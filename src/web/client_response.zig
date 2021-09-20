//! Client response, allows you to read HTTP contents of arbitrary length at any time, or fully read contents, and
//! cancel the request mid-way if so desired.

const std = @import("std");
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

const ClientResponse = @This();
const logger = std.log.scoped(.@"zupnp.web.ClientResponse");

/// HTTP status code.
http_status: c_int,

/// Content type.
content_type: ?[:0]const u8,

/// Content length.
content_length: ?u32,

timeout: c_int,
// keepalive: bool,
handle: *zupnp.web.Client.Handle,

/// Read full contents of HTTP request into a memory allocated string.
/// Caller owns the returned string.
pub fn readAll(self: *ClientResponse, allocator: *std.mem.Allocator) ![:0]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    var chunk: [1024]u8 = undefined;
    while (try self.readChunk(&chunk)) |chunk_read| {
        try buf.appendSlice(chunk_read);
    }
    return try buf.toOwnedSliceSentinel(0);
}

/// Read contents of HTTP request into buffer and returns a slice if anything was read.
/// If there's nothing to read, the request is cancelled and null is returned.
pub fn readChunk(self: *ClientResponse, buf: []u8) !?[]const u8 {
    errdefer self.cancel();
    var size = buf.len;
    if (c.is_error(c.UpnpReadHttpResponse(self.handle.handle, buf.ptr, &size, self.timeout))) |err| {
        logger.err("Failed reading HTTP response: {s}", .{err});
        return zupnp.Error;
    }
    if (size == 0) {
        self.cancel();
        return null;
    }
    return buf[0..size];
}

/// Cancel the current request and, if keepalive was unset, also closes the connection to the server.
pub fn cancel(self: *ClientResponse) void {
    logger.debug("Cancel err {d}", .{c.UpnpCancelHttpGet(self.handle.handle)});
    // if (!self.keepalive) {
        self.handle.close();
        // Due to the nature of pupnp, once the handle is closed, content type get clobbered
        self.content_type = null;
    // }
}
