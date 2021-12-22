// http://www.upnp.org/schemas/device-1-0.xsd
const zupnp = @import("../../lib.zig");

pub const Device = struct {
    root: struct {
        __attributes__: struct {
            xmlns: []const u8 = "urn:schemas-upnp-org:device-1-0",
        } = .{},
        specVersion: struct {
            major: u8 = 1,
            minor: u8 = 0,
        } = .{},
        device: zupnp.util.structure.concatStructDeclarations(.{
            struct {
                deviceType: []const u8,
                serviceList: struct {
                    service: []const ServiceDefinition,
                },
            },
            UserDefinedDeviceParameters
        })
    }
};

pub const UserDefinedDeviceParameters = struct {
    UDN: []const u8, // use zupnp.util.uuid.generateUuid() if you don't care
    friendlyName: []const u8,
    manufacturer: []const u8,
    manufacturerURL: ?[]const u8 = null,
    modelDescription: ?[]const u8 = null,
    modelName: []const u8,
    modelNumber: ?[]const u8 = null,
    modelURL: ?[]const u8 = null,
    serialNumber: ?[]const u8 = null,
    UPC: ?[]const u8 = null,
    iconList: ?struct {
        icon: []const Icon,
    } = null,
};

pub const Icon = struct {
    mimetype: []const u8,
    width: usize,
    height: usize,
    depth: u8,
    url: []const u8,
};

pub const ServiceDefinition = struct {
    serviceType: []const u8,
    serviceId: []const u8,
    SCPDURL: []const u8,
    controlURL: []const u8,
    eventSubURL: []const u8,
};

pub const DeviceServiceDefinition = struct {
    service_type: [:0]const u8,
    service_id: [:0]const u8,
    scpd_xml: [:0]const u8,
};
