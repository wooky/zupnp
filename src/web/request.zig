const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;

const c = @import("../c.zig");
const zupnp = @import("../lib.zig");

const logger = std.log.scoped(.@"zupnp.web.request");

pub const Endpoint = struct {
    pub const DeinitFn = fn(*c_void) void;
    pub const GetFn = fn(*c_void, *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse;
    pub const PostFn = fn(*c_void, *const zupnp.web.ServerPostRequest) bool;

    instance: *c_void,
    allocator: *std.mem.Allocator,
    deinitFn: ?DeinitFn,
    getFn: ?GetFn,
    postFn: ?PostFn,

    pub fn fromCookie(cookie: ?*const c_void) *Endpoint {
        return c.mutate(*Endpoint, cookie);
    }
};

pub const RequestCookie = struct {
    arena: ArenaAllocator,
    request: union (enum) {
        Get: GetRequest,
        Chunked: ChunkedRequest,
    },

    pub fn create(allocator: *std.mem.Allocator) !*RequestCookie {
        var req = try allocator.create(RequestCookie);
        req.* = .{
            .arena = ArenaAllocator.init(allocator),
            .request = undefined,
        };
        return req;
    }

    pub fn fromVoidPointer(ptr: ?*const c_void) *RequestCookie {
        return c.mutate(*RequestCookie, ptr);
    }

    pub fn deinit(self: *RequestCookie) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self);
    }

    pub fn toRequest(self: *RequestCookie) !*Request {
        var req = try self.arena.allocator.create(Request);
        req.* = switch (self.request) {
            .Get => |*get| .{ .Get = get },
            .Chunked => |*chunked| .{ .Chunked = chunked },
        };
        return req;
    }
};

pub const Request = union (enum) {
    Get: *GetRequest,
    Post: PostRequest,
    Chunked: *ChunkedRequest,

    pub fn fromFileHandle(hnd: c.UpnpWebFileHandle) *Request {
        return c.mutate(*Request, hnd);
    }

    pub fn toFileHandle(self: *Request) c.UpnpWebFileHandle {
        return @ptrCast(c.UpnpWebFileHandle, self);
    }
};

pub const GetRequest = struct {
    contents: []const u8,
    seek_pos: usize,

    pub fn init(contents: []const u8) GetRequest {
        return .{
            .contents = contents,
            .seek_pos = 0,
        };
    }

    pub fn deinit(self: *GetRequest) void {
        // Do nothing.
    }

    pub fn read(self: *GetRequest, buf: [*c]u8, buflen: usize) callconv(.C) c_int {
        const bytes_written = std.math.max(buflen, self.contents.len - self.seek_pos);
        std.mem.copy(u8, buf[0..buflen], self.contents[self.seek_pos..self.seek_pos + bytes_written]);
        return @intCast(c_int, bytes_written);
    }

    pub fn seek(self: *GetRequest, offset: c.off_t, origin: c_int) callconv(.C) c_int {
        self.seek_pos = @intCast(usize, offset + switch (origin) {
            c.SEEK_CUR => @intCast(c_long, self.seek_pos),
            c.SEEK_END => @intCast(c_long, self.contents.len),
            c.SEEK_SET => 0,
            else => {
                logger.err("Unexpected GET seek origin type {d}", .{origin});
                return -1;
            }
        });
        return 0;
    }

    pub fn write(self: *GetRequest, buf: [*c]u8, buflen: usize) callconv(.C) c_int {
        logger.err("Called write() on GET request", .{});
        return -1;
    }

    pub fn close(self: *GetRequest) callconv(.C) c_int {
        return 0;
    }
};

pub const PostRequest = struct {
    endpoint: *Endpoint,
    filename: [:0]const u8,
    contents: std.ArrayList(u8),
    seek_pos: usize,

    pub fn createRequest(endpoint: *Endpoint, filename: [*c]const u8) !*Request {
        var req = try endpoint.allocator.create(Request);
        req.* = .{ .Post = .{
            .endpoint = endpoint,
            .filename = std.mem.sliceTo(filename, 0),
            .contents = std.ArrayList(u8).init(endpoint.allocator),
            .seek_pos = 0,
        } };
        return req;
    }

    pub fn deinit(self: *PostRequest) void {
        self.contents.deinit();
    }

    pub fn read(self: *PostRequest, buf: [*c]u8, buflen: usize) callconv(.C) c_int {
        logger.err("Called read() on POST request", .{});
        return -1;
    }

    pub fn seek(self: *PostRequest, offset: c.off_t, origin: c_int) callconv(.C) c_int {
        logger.err("Called seek() on POST request", .{});
        return -1;
    }

    pub fn write(self: *PostRequest, buf: [*c]u8, buflen: usize) callconv(.C) c_int {
        self.contents.appendSlice(buf[0..buflen]) catch |err| {
            logger.err("Failed to write POST request to buffer: {s}", .{err});
            return -1;
        };
        return @intCast(c_int, buflen);
    }

    pub fn close(self: *PostRequest) callconv(.C) c_int {
        var arena = ArenaAllocator.init(self.endpoint.allocator);
        defer arena.deinit();
        const server_request = zupnp.web.ServerPostRequest {
            .allocator = &arena.allocator,
            .filename = self.filename,
            .contents = self.contents.items,
        };
        _ = (self.endpoint.postFn.?)(self.endpoint.instance, &server_request);
        return 0;
    }
};

pub const ChunkedRequest = struct {
    handler: zupnp.web.ServerResponse.ChunkedInternal.Handler,
    seek_pos: usize,

    pub fn init(handler: zupnp.web.ServerResponse.ChunkedInternal.Handler) ChunkedRequest {
        return .{
            .handler = handler,
            .seek_pos = 0,
        };
    }

    pub fn deinit(self: *ChunkedRequest) void {
        // Do nothing.
    }

    pub fn read(self: *ChunkedRequest, buf: [*c]u8, buflen: usize) callconv(.C) c_int {
        return @intCast(c_int, self.handler.getChunkFn(self.handler.instance, buf[0..buflen], self.seek_pos));
    }

    pub fn seek(self: *ChunkedRequest, offset: c.off_t, origin: c_int) callconv(.C) c_int {
        self.seek_pos = @intCast(usize, offset + switch (origin) {
            c.SEEK_CUR => @intCast(c_long, self.seek_pos),
            c.SEEK_SET => 0,
            c.SEEK_END => {
                logger.err("Unexpected SEEK_END for chunked request", .{});
                return -1;
            },
            else => {
                logger.err("Unexpected chunked seek origin type {d}", .{origin});
                return -1;
            }
        });
        return 0;
    }

    pub fn write(self: *ChunkedRequest, buf: [*c]u8, buflen: usize) callconv(.C) c_int {
        logger.err("Called write() on chunked request", .{});
        return -1;
    }

    pub fn close(self: *ChunkedRequest) callconv(.C) c_int {
        return 0;
    }
};
