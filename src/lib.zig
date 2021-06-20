pub const upnp = @import("upnp/index.zig");
pub const web = @import("web/index.zig");
pub const xml = @import("xml/index.zig");

pub const Error = error.UPnPError;

pub const ZUPnP = struct {
    const c = @import("c.zig");
    const std = @import("std");
    const Allocator = std.mem.Allocator;

    pub const Config = struct {
        if_name: ?[:0]const u8 = null,
        port: u16 = 0,
    };

    allocator: *Allocator,
    server: web.Server,

    pub fn init(allocator: *Allocator, config: Config) !ZUPnP {
        if (c.UpnpInit2(config.if_name orelse null, config.port) != c.UPNP_E_SUCCESS) {
            return error.UPnPError;
        }
        return ZUPnP {
            .allocator = allocator,
            .server = web.Server.init(allocator),
        };
    }

    pub fn deinit(self: *ZUPnP) void {
        self.server.deinit();
        _ = c.UpnpFinish();
    }
};
