// http://upnp.org/specs/av/UPnP-av-ContentDirectory-v1-Service.pdf

pub const Error = enum(c_int) {
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

pub const ContentDirectoryState = struct {
    SystemUpdateID: [:0]const u8,
};

pub const GetSearchCapabilitiesOutput = struct {
    pub const action_name = "GetSearchCapabilities";

    SearchCaps: [:0]const u8,
};

pub const GetSortCapabilitiesOutput = struct {
    pub const action_name = "GetSortCapabilities";

    SortCaps: [:0]const u8,
};

pub const GetSystemUpdateIdOutput = struct {
    pub const action_name = "GetSystemUpdateID";

    Id: [:0]const u8,
};

// TODO ideally all of []const u8 should be [:0]const u8
pub const BrowseInput = struct {
    @"u:Browse": struct {
        ObjectID: []const u8,
        BrowseFlag: []const u8,
        Filter: []const u8,
        StartingIndex: u32,
        RequestedCount: u32,
        SortCriteria: []const u8,
    }
};

// TODO some of the fields are not stringy, however the ActionResult function does not accept non-string fields.
// Revert to string when that gets implemented.
pub const BrowseOutput = struct {
    pub const action_name = "Browse";

    Result: [:0]const u8,
    NumberReturned: [:0]const u8, // u32
    TotalMatches: [:0]const u8, // u32
    UpdateID: [:0]const u8, // u32
};

// http://www.upnp.org/schemas/av/didl-lite-v2.xsd

pub const DIDLLite = struct {
    @"DIDL-Lite": struct {
        __attributes__: struct {
            @"xmlns:dc": []const u8 = "http://purl.org/dc/elements/1.1/",
            @"xmlns:upnp": []const u8 = "urn:schemas-upnp-org:metadata-1-0/upnp/",
            xmlns: []const u8 = "urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/",
        } = .{},
        container: ?[]const Container = null,
        item: ?[]const Item = null,
    }
};

// TODO some of these attributes are []const u8, even though they should be numeric.
// Currently our XML implementation doesn't support numeric attributes.
// Change back to numeric when implementation is made.

pub const Container = struct {
    __attributes__: struct {
        id: []const u8,
        parentID: []const u8 = "0",
        restricted: []const u8 = "0", // bool TODO bool needs to be converted to 0 or 1
        searchable: ?[]const u8 = null, // bool TODO bool needs to be converted to 0 or 1
        childCount: ?[]const u8 = null, // usize
    },
    @"dc:title": []const u8,
    @"upnp:class": []const u8,
    res: ?[]const Res = null,
    item: ?[]const Item = null,
    // container: []Container, // TODO XML parser doesn't support cyclic fields
};

pub const Item = struct {
    __attributes__: struct {
        id: []const u8,
        parentID: []const u8 = "0",
        restricted: []const u8 = "0", // bool TODO bool needs to be converted to 0 or 1
        refID: ?[]const u8 = null,
    },
    @"dc:title": []const u8,
    @"upnp:class": []const u8,
    res: ?[]const Res = null,
};

pub const Res = struct {
    __attributes__: struct {
        protocolInfo: []const u8,
        importUri: ?[]const u8 = null,
        size: ?[]const u8 = null, // ?usize
        duration: ?[]const u8 = null,
        bitrate: ?[]const u8 = null, // ?usize
        sampleFrequency: ?[]const u8 = null, // ?usize
        bitsPerSample: ?[]const u8 = null, // ?u8
        nrAudioChannels: ?[]const u8 = null, // ?u8
        resolution: ?[]const u8 = null,
        colorDepth: ?[]const u8 = null, // ?u8
        protection: ?[]const u8 = null,
    },
    __item__: []const u8,
};
