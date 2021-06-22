const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

const Server = @This();
const logger = std.log.scoped(.@"zupnp.web.Server");
var no_file_handle: u8 = 0;

const Endpoint = struct {
    const DeinitFn = fn(*c_void) void;
    const GetFn = fn(*c_void, *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse;
    const PostFn = fn(*c_void, *const zupnp.web.ServerPostRequest) bool;

    instance: *c_void,
    allocator: *Allocator,
    deinitFn: ?DeinitFn,
    getFn: ?GetFn,
    postFn: ?PostFn,
};

const RequestCookie = struct {
    arena: ArenaAllocator,
    contents: []const u8,
    seek_pos: usize,
};

arena: ArenaAllocator,
base_url: ?[:0]const u8 = null,
endpoints: std.ArrayList(Endpoint),
static_root_dir: ?[:0]const u8 = null,

pub fn init(allocator: *Allocator) Server {
    logger.debug("Callback init: GetInfo {d}; Open {d}; Read {d}; Seek {d}; Write {d}; Close {d}", .{
        c.UpnpVirtualDir_set_GetInfoCallback(getInfo),
        c.UpnpVirtualDir_set_OpenCallback(open),
        c.UpnpVirtualDir_set_ReadCallback(read),
        c.UpnpVirtualDir_set_SeekCallback(seek),
        c.UpnpVirtualDir_set_WriteCallback(write),
        c.UpnpVirtualDir_set_CloseCallback(close),
    });

    return Server {
        .arena = ArenaAllocator.init(allocator),
        .endpoints = std.ArrayList(Endpoint).init(allocator),
    };
}

pub fn deinit(self: *Server) void {
    for (self.endpoints.items) |endpoint| {
        if (endpoint.deinitFn) |deinitFn| {
            deinitFn(endpoint.instance);
        }
    }
    self.base_url = null;
    self.endpoints.deinit();
    self.arena.deinit();
}

pub fn createEndpoint(self: *Server, comptime T: type, config: anytype, destination: [:0]const u8) !*T {
    var instance = try self.arena.allocator.create(T);
    errdefer self.arena.allocator.destroy(instance);
    if (@hasDecl(T, "prepare")) {
        try instance.prepare(config);
    }

    try self.endpoints.append(.{
        // TODO allow passing in struct with no in-memory representation
        // Easiest would be to turn `instance` to ?*c_void
        .instance = @ptrCast(*c_void, instance),
        .allocator = &self.arena.allocator,
        .deinitFn = mutateEndpointCallback(T, "deinit", Endpoint.DeinitFn),
        .getFn = mutateEndpointCallback(T, "get", Endpoint.GetFn),
        .postFn = mutateEndpointCallback(T, "post", Endpoint.PostFn),
    });
    errdefer { _ = self.endpoints.pop(); }

    var old_cookie: ?*c_void = undefined;
    if (c.is_error(c.UpnpAddVirtualDir(destination, @ptrCast(*const c_void, &self.endpoints.items[self.endpoints.items.len - 1]), &old_cookie))) |err| {
        logger.err("Failed to add endpoint: {s}", .{err});
        return zupnp.Error;
    }
    if (old_cookie != null) {
        return zupnp.Error;
    }

    logger.info("Added endpoint {s}", .{destination});
    return instance;
}

pub fn start(self: *Server) !void {
    const err_code = if (self.static_root_dir) |srd|
        c.UpnpSetWebServerRootDir(srd)
    else
        c.UpnpEnableWebserver(1)
    ;
    if (c.is_error(err_code)) |err| {
        logger.err("Failed to start server: {s}", .{err});
        return zupnp.Error;
    }
    self.base_url = try std.fmt.allocPrintZ(&self.arena.allocator, "http://{s}:{d}", .{
        c.UpnpGetServerIpAddress(),
        c.UpnpGetServerPort()
    });
    logger.notice("Started listening on {s}", .{self.base_url});
}

pub fn stop(self: *Server) void {
    if (self.base_url != null) {
        self.base_url = null;
    }
    c.UpnpSetWebServerRootDir(null);
    logger.notice("Stopped listening", .{});
}

fn getInfo(filename_c: [*c]const u8, info: ?*c.UpnpFileInfo, cookie: ?*const c_void, request_cookie: [*c]?*const c_void) callconv(.C) c_int {
    const filename = std.mem.sliceTo(filename_c, 0);
    logger.debug("GET {s}", .{filename});

    const endpoint = fetchEndpoint(cookie);
    if (endpoint.getFn == null) {
        logger.debug("No GET endpoint defined", .{});
        return -1;
    }
    
    var arena = ArenaAllocator.init(endpoint.allocator);
    const request = zupnp.web.ServerGetRequest {
        .allocator = &arena.allocator,
        .filename = filename,
    };

    const response = (endpoint.getFn.?)(endpoint.instance, &request);
    var req_cookie: ?*RequestCookie = null;
    var return_code: c_int = 0;
    var is_readable = true;
    switch (response) {
        .NotFound => return_code = -1,
        .Forbidden => is_readable = false,
        .Chunked => {},
        .Contents => |cnt| blk: {
            req_cookie = arena.allocator.create(RequestCookie) catch break :blk;
            req_cookie.?.arena = arena;
            req_cookie.?.contents = cnt.contents;
            req_cookie.?.seek_pos = 0;
            if (cnt.content_type) |content_type| {
                logger.debug("ContentType err {d}", .{c.UpnpFileInfo_set_ContentType(info, content_type)});
            }
            logger.debug("FileLength err {d}", .{c.UpnpFileInfo_set_FileLength(info, @intCast(c_long, cnt.contents.len))});
        }
    }

    logger.debug("IsReadable err {d}", .{c.UpnpFileInfo_set_IsReadable(info, @boolToInt(is_readable))});

    if (req_cookie) |rc| {
        request_cookie.* = rc;
    }
    else {
        arena.deinit();
    }

    return return_code;
}

fn open(filename_c: [*c]const u8, mode: c.enum_UpnpOpenFileMode, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c.UpnpWebFileHandle {
    // UPNP_READ (i.e. GET) was already handled under get_info

    if (mode == .UPNP_WRITE) {
        const filename = std.mem.sliceTo(filename_c, 0);
        logger.debug("POST {s}", .{filename});
        const endpoint = fetchEndpoint(cookie);
        if (endpoint.postFn == null) {
            logger.debug("No POST endpoint defined", .{});
            return null;
        }

        var request = endpoint.allocator.create(zupnp.web.ServerPostRequest) catch |err| {
            logger.err("Failed to create POST request object: {s}", .{err});
            return null;
        };
        request.filename = filename;
        request.contents = std.ArrayList(u8).init(endpoint.allocator);
        return @ptrCast(c.UpnpWebFileHandle, request);
    }
    return @ptrCast(c.UpnpWebFileHandle, &no_file_handle);
}

fn read(file_handle: c.UpnpWebFileHandle, buf: [*c]u8, buflen: usize, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    const request = fetchRequestCookie(request_cookie);
    const bytes_written = std.math.max(buflen, request.contents.len - request.seek_pos);
    std.mem.copy(u8, buf[0..buflen], request.contents[request.seek_pos..request.seek_pos + bytes_written]);
    return @intCast(c_int, bytes_written);
}

fn seek(file_handle: c.UpnpWebFileHandle, offset: c.off_t, origin: c_int, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    var request = fetchRequestCookie(request_cookie);
    request.seek_pos = @intCast(usize, offset + switch (origin) {
        c.SEEK_CUR => @intCast(c_long, request.seek_pos),
        c.SEEK_END => @intCast(c_long, request.contents.len),
        c.SEEK_SET => 0,
        else => return -1
    });
    return 0;
}

fn write(file_handle: c.UpnpWebFileHandle, buf: [*c]u8, buflen: usize, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    var request = fetchPostRequest(file_handle);
    request.contents.appendSlice(buf[0..buflen]) catch |err| {
        logger.err("Failed to write POST request to buffer: {s}", .{err});
        return -1;
    };
    return @intCast(c_int, buflen);
}

fn close(file_handle: c.UpnpWebFileHandle, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    // GET
    if (request_cookie != null) {
        var request = fetchRequestCookie(request_cookie);
        request.arena.deinit();
        return 0;
    }

    // POST
    var request = fetchPostRequest(file_handle);
    defer request.contents.deinit();
    const endpoint = fetchEndpoint(cookie);
    var arena = ArenaAllocator.init(endpoint.allocator);
    defer arena.deinit();
    request.allocator = &arena.allocator;
    _ = (endpoint.postFn.?)(endpoint.instance, request);
    return 0;
}

fn fetchEndpoint(ptr: ?*const c_void) *Endpoint {
    return @intToPtr(*Endpoint, @ptrToInt(ptr));
}

fn fetchRequestCookie(ptr: ?*const c_void) *RequestCookie {
    return @intToPtr(*RequestCookie, @ptrToInt(ptr));
}

fn fetchPostRequest(ptr: c.UpnpWebFileHandle) *zupnp.web.ServerPostRequest {
    return @ptrCast(*zupnp.web.ServerPostRequest, @alignCast(@alignOf(*zupnp.web.ServerPostRequest), ptr));
}

fn mutateEndpointCallback(
    comptime InstanceType: type,
    comptime callback_fn_name: []const u8,
    comptime EndpointType: type
) ?EndpointType {
    if (!@hasDecl(InstanceType, callback_fn_name)) {
        return null;
    }

    const callback_fn = @field(InstanceType, callback_fn_name);
    const callback_fn_info = @typeInfo(@TypeOf(callback_fn)).Fn;
    const endpoint_type_info = @typeInfo(EndpointType).Fn;
    if (callback_fn_info.return_type.? != endpoint_type_info.return_type.?) {
        @compileError("Wrong callback return type");
    }
    if (callback_fn_info.args.len != endpoint_type_info.args.len) {
        @compileError("Callback has wrong number of arguments");
    }
    inline for (callback_fn_info.args) |arg, i| {
        if (i == 0 and arg.arg_type != *InstanceType) {
            @compileError("Argument 1 has wrong type");
        }
        if (i > 0 and arg.arg_type.? != endpoint_type_info.args[i].arg_type.?) {
            @compileError("Argument " ++ i + 1 ++ " has wrong type");
        }
    }

    return @intToPtr(EndpointType, @ptrToInt(callback_fn));
}
