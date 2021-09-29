const std = @import("std");
const c = @import("../c.zig");
const SocketAddress = std.x.os.Socket.Address;

const ClientAddress = @This();
const logger = std.log.scoped(.@"zupnp.util.ClientAddress");

socket_address: SocketAddress,
buf: [128]u8 = undefined,
buf_len: u8 = undefined,

pub fn fromSockaddStorage(in: *const c.sockaddr_storage) ClientAddress {
    var client_address = ClientAddress {
        .socket_address = std.x.os.Socket.Address.fromNative(@ptrCast(*const std.os.sockaddr, in)),
    };
    populateString(&client_address) catch |err| {
        logger.err("Failed to get IP address of client: {s}", .{err});
        client_address.buf_len = 0;
    };
    return client_address;
}

fn populateString(client_address: *ClientAddress) !void {
    var fbs = std.io.fixedBufferStream(&client_address.buf);
    try client_address.socket_address.format("", .{}, fbs.writer());
    client_address.buf_len = @intCast(u8, try fbs.getPos());
    _ = try fbs.write("\x00");
}

pub inline fn toString(self: *const ClientAddress) [:0]const u8 {
    return if (self.buf_len == 0)
        "unknown"
    else
        self.buf[0..self.buf_len:0];
}
