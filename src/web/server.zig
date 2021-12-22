const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");
const request = @import("request.zig");

const Server = @This();
const logger = std.log.scoped(.@"zupnp.web.Server");

arena: ArenaAllocator,
base_url: ?[:0]const u8 = null,
endpoints: std.ArrayList(request.Endpoint),
static_root_dir: ?[:0]const u8 = null,

pub fn init(allocator: Allocator) Server {
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
        .endpoints = std.ArrayList(request.Endpoint).init(allocator),
    };
}

pub fn deinit(self: *Server) void {
    for (self.endpoints.items) |endpoint| {
        switch (endpoint.callbacks) {
            .WithInstance => |cb| if (cb.deinitFn) |deinitFn| deinitFn(cb.instance),
            .WithoutInstance => |cb| if (cb.deinitFn) |deinitFn| deinitFn(),
        }
    }
    self.base_url = null;
    self.endpoints.deinit();
    self.arena.deinit();
}

/// FIXME if endpoint is created and Server (or ZUPnP) object's address is changed, a crash is guaranteed when making a request to that endpoint.
pub fn createEndpoint(self: *Server, comptime T: type, config: anytype, destination: [:0]const u8) !*T {
    var instance = try self.arena.allocator().create(T);
    errdefer self.arena.allocator().destroy(instance);
    if (@hasDecl(T, "prepare")) {
        try instance.prepare(config);
    }

    // TODO clean up this nuclear spill
    try self.endpoints.append(.{
        .allocator = self.arena.allocator(),
        .callbacks =
            if (@bitSizeOf(T) == 0) .{ .WithoutInstance = .{
                .deinitFn = c.mutateCallback(T, "deinit", std.meta.Child(std.meta.fieldInfo(std.meta.TagPayload(request.Endpoint.Callbacks, .WithoutInstance), .deinitFn).field_type)),
                .getFn = c.mutateCallback(T, "get", std.meta.Child(std.meta.fieldInfo(std.meta.TagPayload(request.Endpoint.Callbacks, .WithoutInstance), .getFn).field_type)),
                .postFn = c.mutateCallback(T, "post", std.meta.Child(std.meta.fieldInfo(std.meta.TagPayload(request.Endpoint.Callbacks, .WithoutInstance), .postFn).field_type)),
            }}
            else .{ .WithInstance = .{
                .instance = instance,
                .deinitFn = c.mutateCallback(T, "deinit", std.meta.Child(std.meta.fieldInfo(std.meta.TagPayload(request.Endpoint.Callbacks, .WithInstance), .deinitFn).field_type)),
                .getFn = c.mutateCallback(T, "get", std.meta.Child(std.meta.fieldInfo(std.meta.TagPayload(request.Endpoint.Callbacks, .WithInstance), .getFn).field_type)),
                .postFn = c.mutateCallback(T, "post", std.meta.Child(std.meta.fieldInfo(std.meta.TagPayload(request.Endpoint.Callbacks, .WithInstance), .postFn).field_type)),
            }}
            ,
    });
    errdefer { _ = self.endpoints.pop(); }

    var old_cookie: ?*anyopaque = undefined;
    if (c.is_error(c.UpnpAddVirtualDir(
        destination,
        @ptrCast(*const anyopaque, &self.endpoints.items[self.endpoints.items.len - 1]),
        &old_cookie
    ))) |err| {
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
    self.base_url = try std.fmt.allocPrintZ(self.arena.allocator(), "http://{s}:{d}", .{
        c.UpnpGetServerIpAddress(),
        c.UpnpGetServerPort()
    });
    logger.info("Started listening on {s}", .{self.base_url});
}

pub fn stop(self: *Server) void {
    if (self.base_url != null) {
        self.base_url = null;
    }
    c.UpnpSetWebServerRootDir(null);
    logger.info("Stopped listening", .{});
}

/// Only used for GET and HEAD requests.
/// TODO optimize for HEAD requests.
fn getInfo(filename_c: [*c]const u8, info: ?*c.UpnpFileInfo, cookie: ?*const anyopaque, request_cookie: [*c]?*const anyopaque) callconv(.C) c_int {
    const filename = std.mem.sliceTo(filename_c, 0);
    const client_address = zupnp.util.ClientAddress.fromSockaddStorage(c.UpnpFileInfo_get_CtrlPtIPAddr(info));
    logger.debug("GET {s} from {s}", .{filename, client_address.toString()});

    const endpoint = request.Endpoint.fromCookie(cookie);
    if (switch (endpoint.callbacks) {
        .WithInstance => |cb| cb.getFn == null,
        .WithoutInstance => |cb| cb.getFn == null,
    }) {
        logger.debug("No GET endpoint defined", .{});
        return -1;
    }
    
    var req_cookie = request.RequestCookie.create(endpoint.allocator) catch |err| {
        logger.err("Failed to create request cookie: {s}", .{err});
        // TODO return early here
        return -1;
    };
    const req = zupnp.web.ServerGetRequest {
        .allocator = req_cookie.arena.allocator(),
        .filename = filename,
        .client_address = &client_address,
    };

    const response = switch (endpoint.callbacks) {
        .WithInstance => |cb| (cb.getFn.?)(cb.instance, &req),
        .WithoutInstance => |cb| (cb.getFn.?)(&req),
    };
    var return_code: c_int = 0;
    var is_readable = true;
    switch (response) {
        .NotFound => return_code = -1,
        .Forbidden => is_readable = false,
        .Contents => |cnt| {
            req_cookie.request = .{ .Get = request.GetRequest.init(cnt.contents) };
            logger.debug("ContentType err {d} FileLength err {d}", .{
                c.UpnpFileInfo_set_ContentType(info, cnt.content_type),
                c.UpnpFileInfo_set_FileLength(info, @intCast(c_long, cnt.contents.len))
            });
            if (cnt.headers) |*headers| {
                headers.addHeadersToList(c.UpnpFileInfo_get_ExtraHeadersList(info)) catch |err| {
                    logger.err("Failed to add headers: {s}", .{err});
                    return -1;
                };
            }
        },
        .Chunked => |chk| {
            req_cookie.request = .{ .Chunked = request.ChunkedRequest.init(chk.handler) };
            logger.debug("ContentType err {d} FileLength err {d}", .{
                c.UpnpFileInfo_set_ContentType(info, chk.content_type),
                c.UpnpFileInfo_set_FileLength(info, c.UPNP_USING_CHUNKED)
            });
            if (chk.headers) |*headers| {
                headers.addHeadersToList(c.UpnpFileInfo_get_ExtraHeadersList(info)) catch |err| {
                    logger.err("Failed to add headers: {s}", .{err});
                    return -1;
                };
            }
        },
    }

    logger.debug("IsReadable err {d}", .{c.UpnpFileInfo_set_IsReadable(info, @boolToInt(is_readable))});

    if (return_code == 0 and is_readable) {
        request_cookie.* = req_cookie;
    }
    else {
        req_cookie.deinit();
    }

    return return_code;
}

fn open(filename_c: [*c]const u8, mode: c.enum_UpnpOpenFileMode, cookie: ?*const anyopaque, request_cookie: ?*const anyopaque) callconv(.C) c.UpnpWebFileHandle {
    // UPNP_READ (i.e. GET) was already handled under get_info

    if (mode == c.UPNP_WRITE) {
        const filename = std.mem.sliceTo(filename_c, 0);
        logger.debug("POST {s}", .{filename});
        const endpoint = request.Endpoint.fromCookie(cookie);
        if (switch (endpoint.callbacks) {
            .WithInstance => |cb| cb.postFn == null,
            .WithoutInstance => |cb| cb.postFn == null,
        }) {
            logger.debug("No POST endpoint defined", .{});
            return null;
        }

        var req = request.PostRequest.createRequest(endpoint, filename) catch |err| {
            logger.err("Failed to create POST request object: {s}", .{err});
            return null;
        };
        return req.toFileHandle();
    }

    var req_cookie = request.RequestCookie.fromVoidPointer(request_cookie);
    const req = req_cookie.toRequest() catch |err| {
        logger.err("Failed to create GET request object: {s}", .{err});
        return null;
    };
    return req.toFileHandle();
}

fn read(file_handle: c.UpnpWebFileHandle, buf: [*c]u8, buflen: usize, _: ?*const anyopaque, _: ?*const anyopaque) callconv(.C) c_int {
    return dispatch(c_int, file_handle, "read", .{buf, buflen});
}

fn seek(file_handle: c.UpnpWebFileHandle, offset: c.off_t, origin: c_int, _: ?*const anyopaque, _: ?*const anyopaque) callconv(.C) c_int {
    return dispatch(c_int, file_handle, "seek", .{offset, origin});
}

fn write(file_handle: c.UpnpWebFileHandle, buf: [*c]u8, buflen: usize, _: ?*const anyopaque, _: ?*const anyopaque) callconv(.C) c_int {
    return dispatch(c_int, file_handle, "write", .{buf, buflen});
}

fn close(file_handle: c.UpnpWebFileHandle, _: ?*const anyopaque, request_cookie: ?*const anyopaque) callconv(.C) c_int {
    const res = dispatch(c_int, file_handle, "close", .{});
    dispatch(void, file_handle, "deinit", .{});
    if (request_cookie) |rc| {
        request.RequestCookie.fromVoidPointer(rc).deinit();
    }
    logger.debug("A connection has been closed", .{});
    return res;
}

// TODO https://github.com/ziglang/zig/issues/7224
fn dispatch(comptime T: type, file_handle: c.UpnpWebFileHandle, comptime fnName: [:0]const u8, params: anytype) T {
    const req = request.Request.fromFileHandle(file_handle);
    return switch (req.*) {
        .Get => |get| @call(.{}, @field(get, fnName), params),
        .Post => |*post| @call(.{}, @field(post, fnName), params),
        .Chunked => |chunked| @call(.{}, @field(chunked, fnName), params),
    };
}
