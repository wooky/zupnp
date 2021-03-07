pub usingnamespace @cImport({
    @cInclude("upnp/upnp.h");
    @cInclude("upnp/upnptools.h");
});

pub fn is_error(err: c_int) ?c_int {
    return if (err == UPNP_E_SUCCESS)
        null
    else
        err
    ;
}
