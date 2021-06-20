pub usingnamespace @cImport({
    @cInclude("upnp/upnp.h");
    @cInclude("upnp/upnptools.h");
});

pub fn is_error(err: c_int) ?[:0]const u8 {
    if (err == UPNP_E_SUCCESS) {
        return null;
    }
    var err_slice: [:0]const u8 = undefined;
    err_slice.ptr = UpnpGetErrorMessage(err);
    err_slice.len = 0;
    while (err_slice[err_slice.len] != 0) : (err_slice.len += 1) {}
    return err_slice;
}
