const std = @import("std");
const zupnp = @import("../main.zig");

const UPnPServer = @This();

server: zupnp.web.Server,

pub fn init(lib: *const zupnp.ZUPnP, allocator: *std.mem.Allocator) !UPnPServer {
    return UPnPServer {
        .server = try zupnp.web.Server.init(lib, allocator),
    };
}

pub fn deinit(self: *UPnPServer) void {
    self.server.deinit();
}
