const std = @import("std");

pub const Endpoint = @import("endpoint.zig");
pub const Server = @import("server.zig");

pub const Request = struct {
    allocator: *std.mem.Allocator,
    filename: [:0]const u8,
};

pub const Response = union(enum) {
    NotFound: void,
    Forbidden: void,
    Chunked: void,
    OK: struct {
        contents: []const u8,
        content_type: [:0]const u8,
    },
};
