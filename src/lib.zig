pub const upnp = @import("upnp/index.zig");
pub const util = @import("util/index.zig");
pub const web = @import("web/index.zig");
pub const xml = @import("xml/index.zig");

pub const Error = error.UPnPError;

/// Main library. Required for most components.
pub const ZUPnP = struct {
    const c = @import("c.zig");
    const std = @import("std");
    const Allocator = std.mem.Allocator;

    const logger = std.log.scoped(.@"zupnp.Zupnp");

    /// Initialization config. Contains reasonable defaults, so it's fine to leave out.
    pub const Config = struct {
        /// Interface name to use. Defaults to first suitable interface.
        if_name: ?[:0]const u8 = null,
        /// Port number to use. Defaults to an "arbitrary" port.
        /// In practice, starts at 49152 and counts upwards until it find a free port.
        port: u16 = 0,
    };

    allocator: Allocator,
    /// Device manager.
    device_manager: upnp.device.Manager,
    /// Embedded web server.
    server: web.Server,

    pub fn init(allocator: Allocator, config: Config) !ZUPnP {
        if (c.is_error(c.UpnpInit2(config.if_name orelse null, config.port))) |err| {
            logger.err("Failed to initialize library: {s}", .{err});
            return error.UPnPError;
        }
        // This is the part where pupnp's logger gets initialized, however that only gets used in debug builds,
        // which the user is 99% unlikely to run, so sucks to suck.
        return ZUPnP {
            .allocator = allocator,
            .device_manager = upnp.device.Manager.init(allocator),
            .server = web.Server.init(allocator),
        };
    }

    pub fn deinit(self: *ZUPnP) void {
        // Must be in this order, otherwise HTTP requests currently processing will crash due to threading issues!
        _ = c.UpnpFinish();
        self.server.deinit();
    }
};
