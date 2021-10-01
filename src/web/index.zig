const std = @import("std");
const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

pub usingnamespace @import("client.zig");
pub const Server = @import("server.zig");

pub const ClientResponse = @import("client_response.zig");
pub const ServerResponse = @import("server_response.zig").ServerResponse;

pub const Headers = @import("headers.zig");

/// Additional parameters to send to the server when making an HTTP request.
pub const ClientRequest = struct {
    /// Headers to send to the server.
    /// TODO this clobbers the "Host" header, so unless you manually add that in, your requests will most likely fail :^)
    headers: ?zupnp.web.Headers = null,

    /// Content type of the contents being sent.
    content_type: ?[:0]const u8 = null,

    /// Contents to send to the server.
    contents: []const u8 = "",

    /// How long to wait for request, in seconds. Set to null to wait indefinitely.
    timeout: ?c_int = null,
};

/// HTTP request sent by a client to a GET endpoint.
pub const ServerGetRequest = struct {
    /// Scratch allocator. Everything using this allocator will be destroyed once the request gets processed.
    allocator: *std.mem.Allocator,

    /// Full path being requested.
    filename: [:0]const u8,

    /// IP address of the client.
    client_address: *const zupnp.util.ClientAddress,
};

/// HTTP request sent by a client to a POST endpoint.
pub const ServerPostRequest = struct {
    /// Scratch allocator. Everything using this allocator will be destroyed once the request gets processed.
    allocator: *std.mem.Allocator,

    /// Full path being requested.
    filename: [:0]const u8,

    /// Contents sent by the client.
    contents: []const u8,

    // TODO IP address of the client.
};

/// HTTP method to make a request.
pub const Method = enum(c_int) {
    PUT = c.UPNP_HTTPMETHOD_PUT,
    DELETE = c.UPNP_HTTPMETHOD_DELETE,
    GET = c.UPNP_HTTPMETHOD_GET,
    HEAD = c.UPNP_HTTPMETHOD_HEAD,
    POST = c.UPNP_HTTPMETHOD_POST,

    pub fn toUpnpMethod(self: Method) c.Upnp_HttpMethod {
        return @intToEnum(c.Upnp_HttpMethod, @enumToInt(self));
    }
};
