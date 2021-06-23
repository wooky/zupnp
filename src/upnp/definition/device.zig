// http://www.upnp.org/schemas/device-1-0.xsd

pub const Device = struct {
    root: struct {
        __attributes__: struct {
            xmlns: "urn:schemas-upnp-org:device-1-0",
        },
        specVersion: struct {
            major: u8 = 1,
            minor: u8 = 0,
        },
        device: struct {
            pub usingnamespace UserDefinedDeviceParameters;
            deviceType: []const u8,
            UDN: []const u8,
            serviceList: []ServiceDefinition,
        },
    }
};

pub const UserDefinedDeviceParameters = struct {
    friendlyName: []const u8,
    manufacturer: []const u8,
    manufacturerURL: ?[]const u8,
    modelDescription: ?[]const u8,
    modelName: []const u8,
    modelNumber: ?[]const u8 = null,
    modelURL: ?[]const u8 = null,
    serialNumber: ?[]const u8 = null,
    UPC: ?[]const u8 = null,
    iconList: ?[]Icon = null,
};

pub const Icon = struct {
    icon: struct {
        mimetype: []const u8,
        width: usize,
        height: usize,
        depth: u8,
        url: []const u8,
    }
};

pub const ServiceDefinition = struct {
    service: struct {
        serviceType: []const u8,
        serviceId: []const u8,
        SCPDURL: []const u8,
        controlURL: []const u8,
        eventSubURL: []const u8,
    }
};