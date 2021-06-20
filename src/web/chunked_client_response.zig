const std = @import("std");
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

const ChunkedClientResponse = @This();
const logger = std.log.scoped(.@"zupnp.web.ChunkedClientResponse");

http_status: c_int,
content_type: [:0]const u8,
content_length: usize,
timeout: c_int,
// keepalive: bool,
handle: *zupnp.web.Client.Handle,

pub fn readChunk(self: *ChunkedClientResponse, buf: []u8) !?[]const u8 {
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

pub fn cancel(self: *ChunkedClientResponse) void {
    logger.debug("Cancel err {d}", .{c.UpnpCancelHttpGet(self.handle.handle)});
    // if (!self.keepalive) {
        self.handle.close();
    // }
}
