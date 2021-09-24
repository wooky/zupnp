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
        .endpoints = std.ArrayList(request.Endpoint).init(allocator),
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

/// FIXME if endpoint is created and Server (or ZUPnP) object's address is changed, a crash is guaranteed when making a request to that endpoint.
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
        .deinitFn = c.mutateCallback(T, "deinit", request.Endpoint.DeinitFn),
        .getFn = c.mutateCallback(T, "get", request.Endpoint.GetFn),
        .postFn = c.mutateCallback(T, "post", request.Endpoint.PostFn),
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

/// Only used for GET and HEAD requests.
/// TODO optimize for HEAD requests.
fn getInfo(filename_c: [*c]const u8, info: ?*c.UpnpFileInfo, cookie: ?*const c_void, request_cookie: [*c]?*const c_void) callconv(.C) c_int {
    const filename = std.mem.sliceTo(filename_c, 0);
    logger.debug("GET {s}", .{filename});

    const endpoint = request.Endpoint.fromCookie(cookie);
    if (endpoint.getFn == null) {
        logger.debug("No GET endpoint defined", .{});
        return -1;
    }
    
    var arena = ArenaAllocator.init(endpoint.allocator);
    const req = zupnp.web.ServerGetRequest {
        .allocator = &arena.allocator,
        .filename = filename,
    };

    const response = (endpoint.getFn.?)(endpoint.instance, &req);
    var req_cookie: ?*request.RequestCookie = null;
    var return_code: c_int = 0;
    var is_readable = true;
    switch (response) {
        .NotFound => return_code = -1,
        .Forbidden => is_readable = false,
        .Contents => |cnt| blk: {
            req_cookie = request.GetRequestCookie.createRequestCookie(&arena, &cnt) catch |err| {
                logger.err("Failed to create GET request cookie: {s}", .{err});
                break :blk;
            };
            if (cnt.content_type) |content_type| {
                logger.debug("ContentType err {d}", .{c.UpnpFileInfo_set_ContentType(info, content_type)});
            }
            logger.debug("FileLength err {d}", .{c.UpnpFileInfo_set_FileLength(info, @intCast(c_long, cnt.contents.len))});
        },
        .Chunked => |chk| blk: {
            req_cookie = request.ChunkedRequestCookie.createRequestCookie(&arena, &chk) catch |err| {
                logger.err("Failed to create chunked request cookie: {s}", .{err});
                break :blk;
            };
            if (chk.content_type) |content_type| {
                logger.debug("ContentType err {d}", .{c.UpnpFileInfo_set_ContentType(info, content_type)});
            }
            logger.debug("FileLength err {d}", .{c.UpnpFileInfo_set_FileLength(info, c.UPNP_USING_CHUNKED)});
        },
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
        const endpoint = request.Endpoint.fromCookie(cookie);
        if (endpoint.postFn == null) {
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
    const req = switch (req_cookie.*) {
        .Get => |*get| get.toRequest(),
        .Chunked => |*chunked| chunked.toRequest(),
    } catch |err| {
        logger.err("Failed to create GET request object: {s}", .{err});
        return null;
    };
    return req.toFileHandle();
}

// TODO all of the following functions should have their switch statements replaced with some comptime magic

fn read(file_handle: c.UpnpWebFileHandle, buf: [*c]u8, buflen: usize, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    logger.warn("sup {*}", .{file_handle});
    const req = request.Request.fromFileHandle(file_handle);
    return switch (req.*) {
        .Get => |*get| get.read(buf, buflen),
        .Post => |*post| post.read(buf, buflen),
        .Chunked => |*chunked| chunked.read(buf, buflen),
    };
}

fn seek(file_handle: c.UpnpWebFileHandle, offset: c.off_t, origin: c_int, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    logger.warn("yo {*}", .{file_handle});
    const req = request.Request.fromFileHandle(file_handle);
    return switch (req.*) {
        .Get => |*get| get.seek(offset, origin),
        .Post => |*post| post.seek(offset, origin),
        .Chunked => |*chunked| chunked.seek(offset, origin),
    };
}

fn write(file_handle: c.UpnpWebFileHandle, buf: [*c]u8, buflen: usize, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    const req = request.Request.fromFileHandle(file_handle);
    return switch (req.*) {
        .Get => |*get| get.write(buf, buflen),
        .Post => |*post| post.write(buf, buflen),
        .Chunked => |*chunked| chunked.write(buf, buflen),
    };
}

fn close(file_handle: c.UpnpWebFileHandle, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    logger.warn("heya {*}", .{file_handle});
    const req = request.Request.fromFileHandle(file_handle);
    return switch (req.*) {
        .Get => |*get| {
            defer get.deinit(req);
            return get.close();
        },
        .Post => |*post| {
            defer post.deinit(req);
            return post.close();
        },
        .Chunked => |*chunked| {
            defer chunked.deinit(req);
            return chunked.close();
        }
    };
}
