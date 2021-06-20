const std = @import("std");
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

const Client = @This();
const logger = std.log.scoped(.@"zupnp.web.Client");

pub const Handle = struct {
    handle: ?*c_void = null,

    pub fn close(self: *Handle) void {
        if (self.handle) |handle| {
            _ = c.UpnpCloseHttpConnection(handle);
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
    close();
}

pub fn request(self: *Client, allocator: *std.mem.Allocator, method: zupnp.web.Method, url: [:0]const u8, client_request: zupnp.web.HttpContents) !zupnp.web.ClientResponse {
    var chunked_response = try self.chunkedRequest(method, url, client_request);
    defer chunked_response.cancel();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    var chunk: [1024]u8 = undefined;
    while (try chunked_response.readChunk(&chunk)) |chunk_read| {
        try buf.appendSlice(chunk_read);
    }
    const contents = try buf.toOwnedSliceSentinel(0);
    return zupnp.web.ClientResponse {
        .http_status = chunked_response.http_status,
        .content_type = chunked_response.content_type,
        .contents = contents,
    };
}

pub fn chunkedRequest(self: *Client, method: zupnp.web.Method, url: [:0]const u8, client_request: zupnp.web.HttpContents) !zupnp.web.ChunkedClientResponse {
    const timeout = self.timeout orelse -1;
    if (c.is_error(c.UpnpOpenHttpConnection(url, &self.handle.handle, timeout))) |err| {
        logger.err("Failed opening HTTP connection: error {d}", .{err});
        return zupnp.Error;
    }
    errdefer self.handle.close();

    if (c.is_error(c.UpnpMakeHttpRequest(method.toUpnpMethod(), url, self.handle.handle, null, client_request.content_type orelse null, @intCast(c_int, client_request.contents.len), timeout))) |_| {
        logger.err("Failed making request to HTTP endpoint", .{});
        return zupnp.Error;
    }

    const contents = @intToPtr([*c]u8, @ptrToInt(client_request.contents.ptr));
    if (client_request.contents.len > 0 and c.is_error(c.UpnpWriteHttpRequest(self.handle.handle, contents, client_request.contents.len, timeout)) != null) {
        logger.err("Failed writing HTTP contents to endpoint", .{});
        return zupnp.Error;
    }

    if (c.is_error(c.UpnpEndHttpRequest(self.handle.handle, timeout))) |_| {
        logger.err("Failed finalizing HTTP contents to endpoint", .{});
        return zupnp.Error;
    }

    var http_status: c_int = undefined;
    var content_type: [*c]u8 = undefined;
    var content_length: c_int = undefined;
    if (c.is_error(c.UpnpGetHttpResponse(self.handle.handle, null, &content_type, &content_length, &http_status, timeout))) |_| {
        logger.err("Failed getting HTTP response", .{});
        return zupnp.Error;
    }
    var content_type_slice: [:0]const u8 = undefined;
    content_type_slice.ptr = content_type;
    content_type_slice.len = 0;
    while (content_type[content_type_slice.len] != 0) : (content_type_slice.len += 1) {}

    return zupnp.web.ChunkedClientResponse {
        .http_status = http_status,
        .content_type = content_type_slice,
        .content_length = @intCast(usize, content_length),
        .timeout = timeout,
        .handle = &self.handle,
    };
}

pub fn close(self: *Client) void {
    self.handle.close();
}
