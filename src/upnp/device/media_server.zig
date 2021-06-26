const std = @import("std");
const zupnp = @import("../../lib.zig");
const DeviceServiceDefinition = zupnp.upnp.definition.DeviceServiceDefinition;

const MediaServer = @This();
const logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer");

pub const device_type = "urn:schemas-upnp-org:device:MediaServer:1";

bogus: bool, // TODO remove me

pub fn prepare(self: *MediaServer, allocator: *std.mem.Allocator, config: void) ![]DeviceServiceDefinition {
    var service_list = try allocator.alloc(DeviceServiceDefinition, 1);
    service_list[0] = ContentDirectory.service_definition;
    return service_list;
}

const ContentDirectory = struct {
    pub const service_definition = DeviceServiceDefinition {
        .service_type = "urn:schemas-upnp-org:service:ContentDirectory:1",
        .service_id = "urn:upnp-org:serviceId:ContentDirectory",
        .scpd_xml = @embedFile("../definition/content_directory.xml"),
    };
};
