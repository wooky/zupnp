const std = @import("std");

pub const HttpContents = struct {
    headers: [][]const u8 = &[_][]const u8{},
    content_type: ?[:0]const u8 = null,
    contents: []const u8 = "",
};

pub const ClientResponse = struct {
    http_status: c_int,
    content_type: [:0]const u8,
    contents: [:0]const u8,
};

pub const ServerRequest = struct {
    allocator: *std.mem.Allocator,
    filename: [:0]const u8,
};

pub const ServerResponse = union(enum) {
    NotFound: void,
    Forbidden: void,
    Chunked: void,
    Contents: HttpContents,
};
