const c = @import("../c.zig");
const ChunkedDeinitFn = fn(*c_void)void;
const ChunkedGetChunkFn = fn(*c_void, [:0]u8, usize)usize;

/// HTTP response to send back to the client.
pub const ServerResponse = union(enum) {
    pub const ContentsParameters = struct {
        /// TODO unused
        headers: [][]const u8 = &[_][]const u8{},

        /// Content type.
        content_type: ?[:0]const u8 = null,

        /// Contents
        contents: []const u8 = "",
    };

    pub const ContentsInternal = struct {
        headers: [][]const u8,
        content_type: ?[:0]const u8,
        contents: []const u8,
    };

    NotFound: void,
    Forbidden: void,
    Contents: ContentsInternal,

    /// Create a 404 Not Found response.
    pub fn notFound() ServerResponse {
        return .{ .NotFound = {} };
    }

    /// Create a 403 Fobidden response.
    pub fn forbidden() ServerResponse {
        return .{ .Forbidden = {} };
    }

    /// Create a 200 OK response with contents.
    pub fn contents(parameters: ContentsParameters) ServerResponse {
        return .{ .Contents = .{
            .headers = parameters.headers,
            .content_type = parameters.content_type,
            .contents = parameters.contents,
        } };
    }
};
