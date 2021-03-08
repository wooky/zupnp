pub const upnp = @import("upnp/index.zig");
pub const web = @import("web/index.zig");
pub const xml = @import("xml/index.zig");

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
