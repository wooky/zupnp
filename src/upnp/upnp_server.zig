const c = @import("../c.zig");
const std = @import("std");
const zupnp = @import("../main.zig");
const Device = zupnp.upnp.Device;

const UPnPServer = @This();
const logger = std.log.scoped(.UPnPServer);

server: zupnp.web.Server,

pub fn init(lib: *const zupnp.ZUPnP, allocator: *std.mem.Allocator) !UPnPServer {
    return UPnPServer {
        .server = try zupnp.web.Server.init(lib, allocator),
    };
}

pub fn deinit(self: *UPnPServer) void {
    self.server.deinit();
}

pub fn addDevice(self: *UPnPServer, device: *Device) !void {
    const udn = "udn:TODO";
    const udn_url = try std.fmt.allocPrint(self.server.allocator, "{}{}", .{self.server.base_url, udn});
    defer self.server.allocator.free(udn_url);

    var schema = try device.createSchema(udn, udn_url);
    defer schema.deinit();
    {
        if (c.is_error(c.UpnpRegisterRootDevice2(c.Upnp_DescType.UPNPREG_BUF_DESC, schema.string, schema.string.len, 1, Device.onEvent, self, &device.handle))) |err| {
            logger.err("Cannot register device: {s}", .{c.UpnpGetErrorMessage(err)});
            return error.UPnPError;
        }
    }
    
    if (c.UpnpSendAdvertisement(device.handle, 100) != c.UPNP_E_SUCCESS) return error.UPnPError;
    logger.info("Added device {}", .{device.friendly_name});
}
