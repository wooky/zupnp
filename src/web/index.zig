const std = @import("std");
const c = @import("../c.zig");

pub const Client = @import("client.zig");
pub const Server = @import("server.zig");

pub const ClientResponse = @import("client_response.zig");
pub const ServerResponse = @import("server_response.zig").ServerResponse;

/// Additional parameters to send to the server when making an HTTP request.
pub const ClientRequest = struct {
    /// TODO unused
    headers: [][]const u8 = &[_][]const u8{},

    /// Content type of the contents being sent.
    content_type: ?[:0]const u8 = null,

    /// Contents to send to the server.
    contents: []const u8 = "",
};

/// HTTP request sent by a client to a GET endpoint.
pub const ServerGetRequest = struct {
    /// Scratch allocator. Everything using this allocator will be destroyed once the request gets processed.
    allocator: *std.mem.Allocator,

    /// Full path being requested.
    filename: [:0]const u8,
};

/// HTTP request sent by a client to a POST endpoint.
pub const ServerPostRequest = struct {
    /// Scratch allocator. Everything using this allocator will be destroyed once the request gets processed.
    allocator: *std.mem.Allocator,

    /// Full path being requested.
    filename: [:0]const u8,

    /// Contents sent by the client.
    contents: []const u8,
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
