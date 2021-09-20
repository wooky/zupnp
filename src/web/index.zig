const std = @import("std");
const c = @import("../c.zig");

pub const ClientResponse = @import("client_response.zig");
pub const Client = @import("client.zig");
pub const Server = @import("server.zig");

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

/// HTTP response to send back to the client.
pub const ServerResponse = union(enum) {
    pub const Contents = struct {
        /// TODO unused
        headers: [][]const u8 = &[_][]const u8{},

        /// Content type.
        content_type: ?[:0]const u8 = null,

        /// Contents
        contents: []const u8 = "",
    };

    /// 404 Not Found.
    NotFound: void,

    /// 403 Forbidden.
    Forbidden: void,

    /// TODO unused
    Chunked: void,

    /// Full contents.
    Contents: Contents,
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
