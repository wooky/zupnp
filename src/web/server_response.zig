const zupnp = @import("../lib.zig");
const c = @import("../c.zig");
const ChunkedDeinitFn = fn(*anyopaque)void;
const ChunkedGetChunkFn = fn(*anyopaque, []u8, usize)usize;

/// HTTP response to send back to the client.
pub const ServerResponse = union(enum) {
    pub const ContentsParameters = struct {
        /// Extra headers to send to the client.
        headers: ?zupnp.web.Headers = null,

        /// Content type.
        content_type: [:0]const u8 = "",

        /// Contents
        contents: []const u8 = "",
    };

    pub const ChunkedParameters = struct {
        /// Extra headers to send to the client.
        headers: ?zupnp.web.Headers = null,

        /// Content type.
        content_type: [:0]const u8 = "",
    };

    pub const ContentsInternal = struct {
        headers: ?zupnp.web.Headers,
        content_type: [:0]const u8,
        contents: []const u8,
    };

    pub const ChunkedInternal = struct {
        pub const Handler = struct {
            instance: *anyopaque,
            deinitFn: ?ChunkedDeinitFn,
            getChunkFn: ChunkedGetChunkFn,
        };

        headers: ?zupnp.web.Headers,
        content_type: [:0]const u8,
        handler: Handler,
    };

    NotFound: void,
    Forbidden: void,
    Contents: ContentsInternal,
    Chunked: ChunkedInternal,

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

    /// Create a 200 OK response with chunked (i.e. streaming) contents.
    pub fn chunked(parameters: ChunkedParameters, handler: anytype) ServerResponse {
        const HandlerType = @typeInfo(@TypeOf(handler)).Pointer.child;
        return .{ .Chunked = .{
            .headers = parameters.headers,
            .content_type = parameters.content_type,
            .handler = .{
                .instance = handler,
                .deinitFn = c.mutateCallback(HandlerType, "deinit", ChunkedDeinitFn),
                .getChunkFn = c.mutateCallback(HandlerType, "getChunk", ChunkedGetChunkFn).?,
            },
        } };
    }
};
