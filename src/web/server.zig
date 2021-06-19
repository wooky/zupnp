const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

const Server = @This();
const logger = std.log.scoped(.Server);

pub const Error = error.UPnPError;

const Endpoint = struct {
    instance: *c_void,
    allocator: *Allocator,
    deinitFn: ?fn(*c_void) void,
    getFn: ?fn(*c_void, *const zupnp.web.ServerRequest) zupnp.web.ServerResponse,
    postFn: ?fn(*c_void, *const zupnp.web.ServerRequest) bool,
};

const RequestCookie = struct {
    arena: ArenaAllocator,
    contents: []const u8,
    seek_pos: usize,
};

allocator: *Allocator,
endpoints: std.ArrayList(Endpoint),
static_root_dir: ?[:0]const u8 = null,

pub fn init(allocator: *Allocator) Server {
    _ = c.UpnpVirtualDir_set_GetInfoCallback(getInfo);
    _ = c.UpnpVirtualDir_set_OpenCallback(open);
    _ = c.UpnpVirtualDir_set_ReadCallback(read);
    _ = c.UpnpVirtualDir_set_SeekCallback(seek);
    _ = c.UpnpVirtualDir_set_CloseCallback(close);

    return Server {
        .allocator = allocator,
        .endpoints = std.ArrayList(Endpoint).init(allocator),
    };
}

pub fn deinit(self: *Server) void {
    for (self.endpoints.items) |endpoint| {
        if (endpoint.deinitFn) |deinitFn| {
            deinitFn(endpoint.instance);
        }
    }
    self.endpoints.deinit();
}

pub fn createEndpoint(self: *Server, comptime T: type, config: anytype, destination: [:0]const u8) !*T {
    var instance = try self.allocator.create(T);
    errdefer self.allocator.destroy(instance);
    if (@hasDecl(T, "prepare")) {
        try instance.prepare(config);
    }

    try self.endpoints.append(.{
        .instance = @ptrCast(*c_void, instance),
        .allocator = self.allocator,
        .deinitFn = if (@hasDecl(T, "deinit")) T.deinit else null,
        .getFn = if (@hasDecl(T, "get")) T.get else null,
        .postFn = if (@hasDecl(T, "post")) T.post else null,
    });
    errdefer { _ = self.endpoints.pop(); }

    var old_cookie: ?*c_void = undefined;
    if (c.is_error(c.UpnpAddVirtualDir(destination, @ptrCast(*const c_void, &self.endpoints.items[self.endpoints.items.len - 1]), &old_cookie))) |_| {
        logger.err("Failed to add endpoint", .{});
        return error.UPnPError;
    }
    if (old_cookie != null) {
        return error.UPnPError;
    }

    return instance;
}

pub fn start(self: *Server) !void {
    const err = if (self.static_root_dir) |srd|
        c.UpnpSetWebServerRootDir(srd)
    else
        c.UpnpEnableWebserver(1)
    ;
    if (err != c.UPNP_E_SUCCESS) {
        return Error;
    }
    logger.notice("Started listening on http://{s}:{d}", .{
        c.UpnpGetServerIpAddress(),
        c.UpnpGetServerPort()
    });
}

pub fn stop(self: *Server) void {
    c.UpnpSetWebServerRootDir(null);
}

fn getInfo(filename_c: [*c]const u8, info: ?*c.UpnpFileInfo, cookie: ?*const c_void, request_cookie: [*c]?*const c_void) callconv(.C) c_int {
    const endpoint = fetchEndpoint(cookie);
    if (endpoint.getFn == null) {
        return -1;
    }

    var filename: [:0]const u8 = undefined;
    filename.ptr = filename_c;
    filename.len = 0;
    while (filename_c[filename.len] != 0) : (filename.len += 1) {}
    
    var arena = ArenaAllocator.init(endpoint.allocator);
    const request = zupnp.web.ServerRequest {
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
                _ = c.UpnpFileInfo_set_ContentType(info, content_type);
            }
            _ = c.UpnpFileInfo_set_FileLength(info, @intCast(c_long, cnt.contents.len));
        }
    }

    _ = c.UpnpFileInfo_set_IsReadable(info, @boolToInt(is_readable));

    if (req_cookie) |rc| {
        request_cookie.* = rc;
    }
    else {
        arena.deinit();
    }

    return return_code;
}

fn open(filename_c: [*c]const u8, mode: c.enum_UpnpOpenFileMode, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c.UpnpWebFileHandle {
    const request = fetchRequestCookie(request_cookie);
    const endpoint = fetchEndpoint(cookie);

    // UPNP_READ (i.e. GET) was already handled under get_info
    if (mode == .UPNP_WRITE and endpoint.postFn == null) {
        request.arena.deinit();
        return null;
    }
    return undefined;
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

fn close(file_handle: c.UpnpWebFileHandle, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    var request = fetchRequestCookie(request_cookie);
    request.arena.deinit();
    return 0;
}

fn fetchEndpoint(ptr: ?*const c_void) *Endpoint {
    return @intToPtr(*Endpoint, @ptrToInt(ptr));
}

fn fetchRequestCookie(ptr: ?*const c_void) *RequestCookie {
    return @intToPtr(*RequestCookie, @ptrToInt(ptr));
}
