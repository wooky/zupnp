const std = @import("std");
const c = @import("../c.zig");

pub const ChunkedClientResponse = @import("chunked_client_response.zig");
pub const Client = @import("client.zig");
pub const Server = @import("server.zig");

pub const ClientRequest = struct {
    headers: [][]const u8 = &[_][]const u8{},
    content_type: ?[:0]const u8 = null,
    contents: []const u8 = "",
};

pub const ClientResponse = struct {
    allocator: *std.mem.Allocator,
    http_status: c_int,
    content_type: ?[:0]const u8,
    contents: [:0]const u8,

    pub fn deinit(self: *ClientResponse) void {
        self.allocator.free(self.contents);
        if (self.content_type) |ct| {
            self.allocator.free(ct);
        }
    }
};

pub const ServerGetRequest = struct {
    allocator: *std.mem.Allocator,
    filename: [:0]const u8,
};

pub const ServerPostRequest = struct {
    allocator: *std.mem.Allocator,
    filename: [:0]const u8,
    contents: std.ArrayList(u8),
};

pub const ServerResponse = union(enum) {
    NotFound: void,
    Forbidden: void,
    Chunked: void,
    Contents: struct {
        headers: [][]const u8 = &[_][]const u8{},
        content_type: ?[:0]const u8 = null,
        contents: []const u8 = "",
    },
};

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
