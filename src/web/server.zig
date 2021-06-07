const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("../c.zig");
const zupnp = @import("../main.zig");

const Server = @This();
const logger = std.log.scoped(.UPnP);

pub const Error = error.UPnPError;

allocator: *Allocator,
base_url: [:0]const u8,

pub fn init(lib: *const zupnp.ZUPnP, allocator: *Allocator) !Server {
    if (c.UpnpSetWebServerRootDir("./web") != c.UPNP_E_SUCCESS) {
        return Error;
    }
    const base_url = try std.fmt.allocPrintZ(allocator, "http://{s}:{}/", .{
        c.UpnpGetServerIpAddress(),
        c.UpnpGetServerPort()
    });

    _ = c.UpnpVirtualDir_set_GetInfoCallback(zupnp.web.Endpoint.getInfo);
    _ = c.UpnpVirtualDir_set_OpenCallback(zupnp.web.Endpoint.open);
    _ = c.UpnpVirtualDir_set_ReadCallback(zupnp.web.Endpoint.read);
    _ = c.UpnpVirtualDir_set_SeekCallback(zupnp.web.Endpoint.seek);
    _ = c.UpnpVirtualDir_set_CloseCallback(zupnp.web.Endpoint.close);

    logger.notice("Server listening on {s}", .{base_url});
    return Server { .allocator = allocator, .base_url = base_url };
}

pub fn deinit(self: *Server) void {
    self.allocator.free(self.base_url);
}

pub fn addEndpoint(self: *Server, endpoint: *const zupnp.web.Endpoint) !void {
    var old_cookie: ?*c_void = undefined;
    if (c.is_error(c.UpnpAddVirtualDir(endpoint.dir, @ptrCast(*const c_void, endpoint), &old_cookie))) |_| {
        logger.err("Failed to add endpoint", .{});
        return error.UPnPError;
    }
    if (old_cookie != null) {
        return error.UPnPError;
    }
}
