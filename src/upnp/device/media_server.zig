const std = @import("std");
const zupnp = @import("../../lib.zig");
const ServiceDefinition = zupnp.upnp.ServiceDefinition;

const MediaServer = @This();
const logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer");

pub const device_type = "urn:schemas-upnp-org:device:MediaServer:1";

bogus: bool, // TODO remove me

pub fn prepare(self: *MediaServer, allocator: *std.mem.Allocator, udn: []const u8, config: void) ![]ServiceDefinition {
    var service_list = try allocator.alloc(ServiceDefinition, 1);
    service_list[0] = .{
        .service = .{
            .serviceType = ContentDirectory.service_type,
            .serviceId = "urn:TODO",
            .SCPDURL = "TODO",
            .controlURL = "TODO",
            .eventSubURL = "TODO",
        }
    };
    return service_list;
}

const ContentDirectory = struct {
    pub const service_type = "urn:schemas-upnp-org:service:ContentDirectory:1";
};
