const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("../c.zig");

const Server = @This();
const logger = std.log.scoped(.UPnP);

pub const Error = error.UPnPError;

allocator: *Allocator,
base_url: [:0]const u8,

pub fn init(allocator: *Allocator) !Server {
    if (c.UpnpInit2(null, 0) != c.UPNP_E_SUCCESS) return Error;
    if (c.UpnpSetWebServerRootDir("./web") != c.UPNP_E_SUCCESS) return Error;
    const base_url = try std.fmt.allocPrintZ(&self.base_url_buf, "http://{s}:{}/", .{
        c.UpnpGetServerIpAddress(),
        c.UpnpGetServerPort()
    });
    logger.notice("Server listening on {}", .{self.base_url});
    return Self { .allocator = allocator, .base_url = base_url };
}

pub fn deinit(self: *Server) void {
    self.allocator.free(self.base_url);
}
