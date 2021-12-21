//! HTTP client, use to download contents from a URL.
//! In order to use HTTPS, libupnp must be built with OpenSSL support.
//! If you're using the libupnp library provided by your distro, it's most likely that there's no HTTPS support.
//! In which case, any calls to request a HTTPS URL will return with an invalid URL error.

const std = @import("std");
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

/// Make an HTTP request and get a response.
pub fn request(method: zupnp.web.Method, url: [:0]const u8, client_request: zupnp.web.ClientRequest) !zupnp.web.ClientResponse {
    const logger = std.log.scoped(.@"zupnp.web.request");
    logger.debug("Establishing a {s} request to {s}", .{method, url});

    const timeout = client_request.timeout orelse -1;
    var handle: ?*anyopaque = undefined;
    if (c.is_error(c.UpnpOpenHttpConnection(url, &handle, timeout))) |err| {
        logger.err("Failed opening HTTP connection: {s}", .{err});
        return zupnp.Error;
    }
    errdefer logger.debug("Close err {d}", .{c.UpnpCloseHttpConnection(handle)});

    var headers_buf = if (client_request.headers) |*headers| try headers.toString(url) else null;
    defer { if (headers_buf) |*hb| hb.deinit(); }
    const headers = if (headers_buf) |*hb| blk: {
        var headers = c.UpnpString_new();
        _ = c.UpnpString_set_StringN(headers, hb.items.ptr, hb.items.len);
        break :blk headers;
    }
    else null;

    if (c.is_error(c.UpnpMakeHttpRequest(
        method.toUpnpMethod(),
        url,
        handle,
        headers,
        client_request.content_type orelse null,
        @intCast(c_int, client_request.contents.len), timeout)
    )) |err| {
        logger.err("Failed making request to HTTP endpoint: {s}", .{err});
        return zupnp.Error;
    }

    if (client_request.contents.len > 0) {
        const contents = c.mutate([*c]u8, client_request.contents.ptr);
        var len = client_request.contents.len;
        if (c.is_error(c.UpnpWriteHttpRequest(handle, contents, &len, timeout))) |err| {
            logger.err("Failed writing HTTP contents to endpoint: {s}", .{err});
            return zupnp.Error;
        }
    }

    if (c.is_error(c.UpnpEndHttpRequest(handle, timeout))) |err| {
        logger.err("Failed finalizing HTTP contents to endpoint: {s}", .{err});
        return zupnp.Error;
    }

    var http_status: c_int = undefined;
    var content_type: [*c]u8 = undefined;
    var content_length: c_int = undefined;
    // TODO be aware that content type is only valid for the duration of the connection
    if (c.is_error(c.UpnpGetHttpResponse(handle, null, &content_type, &content_length, &http_status, timeout))) |err| {
        logger.err("Failed getting HTTP response: {s}", .{err});
        return zupnp.Error;
    }
    var content_type_slice = if (content_type != null) std.mem.sliceTo(content_type, 0) else null;

    return zupnp.web.ClientResponse {
        .http_status = http_status,
        .content_type = content_type_slice,
        .content_length = if (content_length < 0) null else @intCast(u32, content_length),
        .timeout = timeout,
        .handle = handle,
    };
}
