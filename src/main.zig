pub const upnp = struct {
    pub const Device = @import("upnp/device.zig");
    pub const Service = @import("upnp/service.zig");
    pub const UPnPServer = @import("upnp/upnp_server.zig");
};

pub const web = struct {
    pub const Endpoint = @import("web/endpoint.zig");
    pub const Server = @import("web/server.zig");
};

pub const xml = struct {
    usingnamespace @import("xml/xml.zig");
    pub const Parser = @import("xml/parser.zig");
    pub const Writer = @import("xml/writer.zig");
};

pub const ZUPnP = struct {
    const c = @import("c.zig");

    pub fn init() !ZUPnP {
        if (c.UpnpInit2(null, 0) != c.UPNP_E_SUCCESS) {
            return error.UPnPError;
        }
        return ZUPnP {};
    }

    pub fn deinit(self: *ZUPnP) void {
        _ = c.UpnpFinish();
    }
};
