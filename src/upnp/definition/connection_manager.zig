// http://upnp.org/specs/av/UPnP-av-ConnectionManager-v1-Service.pdf

pub const Error = enum(c_int) {
    InvalidAction = 401,
    InvalidArgs = 402,
    InvalidVar = 404,
    ActionFailed = 501,
    InvalidConnectionReference = 706,

    pub fn toErrorCode(self: Error) c_int {
        return @enumToInt(self);
    }
};

pub const GetProtocolInfoOutput = struct {
    Source: [:0]const u8,
    Sink: [:0]const u8,
};

pub const GetCurrentConnectionIDsOutput = struct {
    ConnectionIDs: [:0]const u8,
};

// TODO some of the fields are not stringy, however the ActionResult function does not accept non-string fields.
// Revert to string when that gets implemented.
pub const GetCurrentConnectionInfoInput = struct {
    ConnectionID: [:0]const u8, // i4
};

// TODO some of the fields are not stringy, however the ActionResult function does not accept non-string fields.
// Revert to string when that gets implemented.
pub const GetCurrentConnectionInfoOutput = struct {
    RcsID: [:0]const u8, // i4
    AVTransportID: [:0]const u8, // i4
    ProtocolInfo: [:0]const u8,
    PeerConnectionManager: [:0]const u8,
    PeerConnectionID: [:0]const u8, // i4
    Direction: [:0]const u8,
    Status: [:0]const u8,
};
