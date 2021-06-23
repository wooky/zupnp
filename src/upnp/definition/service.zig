// http://www.upnp.org/schemas/service-1-0.xsd

pub const Service = struct {
    scpd: struct {
        __attributes__: struct {
            xmlns: []const u8 = "urn:schemas-upnp-org:service-1-0",
        },
        specVersion: struct {
            major: u8 = 1,
            minor: u8 = 0,
        },
        actionList: ?[]Action = null,
        serviceStateTable: []StateVariable = null,
    }
};

pub const Action = struct {
    action: struct {
        name: []const u8,
        argumentList: ?[]Argument = null,
    }
};

pub const Argument = struct {
    argument: struct {
        name: []const u8,
        direction: []const u8,
        relatedStateVariable: []const u8,
    }
};

pub const StateVariable = struct {
    stateVariable: struct {
        __attributes__: struct {
            sendEvents: u1 = 1,
            multicast: u1 = 0,
        },
        name: []const u8,
        dataType: []const u8,
        defaultValue: ?[]const u8 = null,
        allowedValueList: ?[]AllowedValue = null,
        allowedValueRange: ?AllowedValueRange = null,
    }
};

pub const AllowedValue = struct {
    allowedValue: []const u8,
};

pub const AllowedValueRange = struct {
    minimum: f64,
    maximum: f64,
    step: ?f64,
};
