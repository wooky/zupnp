pub usingnamespace @cImport({
    @cInclude("upnp/upnp.h");
    @cInclude("upnp/upnptools.h");
});

pub fn is_error(err: c_int) ?[:0]const u8 {
    if (err == UPNP_E_SUCCESS) {
        return null;
    }
    return @import("std").mem.sliceTo(UpnpGetErrorMessage(err), 0);
}
