const std = @import("std");
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

const Client = @This();
const logger = std.log.scoped(.@"zupnp.web.Client");

pub const Handle = struct {
    handle: ?*c_void = null,

    pub fn close(self: *Handle) void {
        if (self.handle) |handle| {
            logger.debug("Close err {d}", .{c.UpnpCloseHttpConnection(handle)});
            self.handle = null;
        }
    }
};

timeout: ?c_int = null,
// keepalive: bool = false,
handle: Handle = .{},

pub fn init() Client {
    return .{};
}

pub fn deinit(self: *Client) void {
    self.close();
}

pub fn request(self: *Client, allocator: *std.mem.Allocator, method: zupnp.web.Method, url: [:0]const u8, client_request: zupnp.web.ClientRequest) !zupnp.web.ClientResponse {
    var chunked_response = try self.chunkedRequest(method, url, client_request);
    defer chunked_response.cancel();

    const content_type = if (chunked_response.content_type) |ct| try allocator.dupeZ(u8, ct) else null;
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    var chunk: [1024]u8 = undefined;
    while (try chunked_response.readChunk(&chunk)) |chunk_read| {
        try buf.appendSlice(chunk_read);
    }
    const contents = try buf.toOwnedSliceSentinel(0);
    return zupnp.web.ClientResponse {
        .allocator = allocator,
        .http_status = chunked_response.http_status,
        .content_type = content_type,
        .contents = contents,
    };
}

pub fn chunkedRequest(self: *Client, method: zupnp.web.Method, url: [:0]const u8, client_request: zupnp.web.ClientRequest) !zupnp.web.ChunkedClientResponse {
    const timeout = self.timeout orelse -1;
    if (c.is_error(c.UpnpOpenHttpConnection(url, &self.handle.handle, timeout))) |err| {
        logger.err("Failed opening HTTP connection: {s}", .{err});
        return zupnp.Error;
    }
    errdefer self.handle.close();

    if (c.is_error(c.UpnpMakeHttpRequest(method.toUpnpMethod(), url, self.handle.handle, null, client_request.content_type orelse null, @intCast(c_int, client_request.contents.len), timeout))) |err| {
        logger.err("Failed making request to HTTP endpoint: {s}", .{err});
        return zupnp.Error;
    }

    if (client_request.contents.len > 0) {
        const contents = c.mutate([*c]u8, client_request.contents.ptr);
        var len = client_request.contents.len;
        if (c.is_error(c.UpnpWriteHttpRequest(self.handle.handle, contents, &len, timeout))) |err| {
            logger.err("Failed writing HTTP contents to endpoint: {s}", .{err});
            return zupnp.Error;
        }
    }

    if (c.is_error(c.UpnpEndHttpRequest(self.handle.handle, timeout))) |err| {
        logger.err("Failed finalizing HTTP contents to endpoint: {s}", .{err});
        return zupnp.Error;
    }

    var http_status: c_int = undefined;
    var content_type: [*c]u8 = undefined;
    var content_length: c_int = undefined;
    // TODO crash occurs here if no content type is set
    if (c.is_error(c.UpnpGetHttpResponse(self.handle.handle, null, &content_type, &content_length, &http_status, timeout))) |err| {
        logger.err("Failed getting HTTP response: {s}", .{err});
        return zupnp.Error;
    }
    var content_type_slice = if (content_type != null) std.mem.sliceTo(content_type, 0) else null;

    return zupnp.web.ChunkedClientResponse {
        .http_status = http_status,
        .content_type = content_type_slice,
        .content_length = if (content_length < 0) null else @intCast(u32, content_length),
        .timeout = timeout,
        .handle = &self.handle,
    };
}

pub fn close(self: *Client) void {
    self.handle.close();
}
