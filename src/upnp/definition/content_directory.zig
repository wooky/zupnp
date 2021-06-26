// http://upnp.org/specs/av/UPnP-av-ContentDirectory-v1-Service.pdf

pub const BrowseInput = struct {
    ObjectID: []const u8,
    BrowseFlag: []const u8,
    Filter: []const u8,
    StartingIndex: u32,
    RequestedCount: u32,
    SortCriteria: []const u8,
};

pub const BrowseOutput = struct {
    Result: []const u8,
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
