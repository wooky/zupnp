// http://upnp.org/specs/av/UPnP-av-ContentDirectory-v1-Service.pdf

pub const Error = enum(c_int) {
    InvalidAction = 401,
    InvalidArgs = 402,
    InvalidVar = 404,
    ActionFailed = 501,
    NoSuchObject = 701,
    InvalidCurrentTagValue = 702,
    InvalidNewTagValue = 703,
    RequiredTag = 704,
    ReadOnlyTag = 705,
    ParameterMismatch = 706,
    UnsupportedOrInvalidSearchCriteria = 708,
    UnsupportedOrInvalidSortCriteria = 709,
    NoSuchContainer = 710,
    RestrictedObject = 711,
    BadMetadata = 712,
    RestrictedParentObject = 713,
    NoSuchSourceResource = 714,
    SourceResourceAccessDenied = 715,
    TransferBusy = 716,
    NoSuchFileTransfer = 717,
    NoSuchDestinationResource = 718,
    DestinationResourceAccessDenied = 719,
    CannotProcessRequest = 720,

    pub fn toErrorCode(self: Error) c_int {
        return @enumToInt(self);
    }
};

pub const GetSearchCapabilitiesOutput = struct {
    SearchCaps: [:0]const u8,
};

pub const GetSortCapabilitiesOutput = struct {
    SortCaps: [:0]const u8,
};

pub const GetSystemUpdateIdOutput = struct {
    Id: [:0]const u8,
};

pub const BrowseInput = struct {
    ObjectID: [:0]const u8,
    BrowseFlag: [:0]const u8,
    Filter: [:0]const u8,
    StartingIndex: u32,
    RequestedCount: u32,
    SortCriteria: [:0]const u8,
};

pub const BrowseOutput = struct {
    Result: [:0]const u8,
    NumberReturned: u32,
    TotalMatches: u32,
    UpdateID: u32,
};

// http://www.upnp.org/schemas/av/didl-lite-v2.xsd

pub const DIDLLite = struct {
    @"DIDL-Lite": struct {
        __attributes__: struct {
            @"xmlns:dc": []const u8 = "http://purl.org/dc/elements/1.1/",
            @"xmlns:upnp": []const u8 = "urn:schemas-upnp-org:metadata-1-0/upnp/",
            xmlns: []const u8 = "urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/",
        },

    }
};

pub const Item = struct {
    __attributes__: struct {
        id: usize,
        parentID: usize,
        restricted: bool,
        refID: ?usize = null,
    },
    @"dc:title": []const u8,
    @"upnp.class": []const u8,
    res: struct {
        __attributes__: struct {
            protocolInfo: []const u8,
            importUri: ?[]const u8 = null,
            size: ?usize = null,
            duration: ?[]const u8 = null,
            bitrate: ?usize = null,
            sampleFrequency: ?usize = null,
            bitsPerSample: ?u8 = null,
            nrAudioChannels: ?u8 = null,
            resolution: ?[]const u8 = null,
            colorDepth: ?u8 = null,
            protection: ?[]const u8 = null,
        },
        __item__: []const u8,
    }
};
