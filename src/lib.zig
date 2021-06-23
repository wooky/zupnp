pub const upnp = @import("upnp/index.zig");
pub const web = @import("web/index.zig");
pub const xml = @import("xml/index.zig");

pub const Error = error.UPnPError;

pub const ZUPnP = struct {
    const c = @import("c.zig");
    const std = @import("std");
    const Allocator = std.mem.Allocator;

    const logger = std.log.scoped(.@"zupnp.Zupnp");

    pub const Config = struct {
        if_name: ?[:0]const u8 = null,
        port: u16 = 0,
    };

    allocator: *Allocator,
    device_manager: upnp.device.Manager,
    server: web.Server,

    pub fn init(allocator: *Allocator, config: Config) !ZUPnP {
        if (c.is_error(c.UpnpInit2(config.if_name orelse null, config.port))) |err| {
            logger.err("Failed to initialize library: {s}", .{err});
            return error.UPnPError;
        }
        // TODO in future releases of pupnp, call UpnpSetLogCallback to redirect logger calls to Zig's logger
        return ZUPnP {
            .allocator = allocator,
            .device_manager = upnp.device.Manager.init(allocator),
            .server = web.Server.init(allocator),
        };
    }

    pub fn deinit(self: *ZUPnP) void {
        self.server.deinit();
        _ = c.UpnpFinish();
    }
};
