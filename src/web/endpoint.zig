const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const c = @import("../c.zig");
const zupnp = @import("../main.zig");

pub const Response = struct {
    contents: []const u8,
    content_type: [:0]const u8 = "text/html",
    is_readable: bool = true,
};

const Request = struct {
    arena: Arena,
    contents: []const u8,
    seek_pos: usize,
};

const Endpoint = @This();
const Handle = fn (*Endpoint, *Allocator, []const u8) ?Response;
const logger = std.log.scoped(.Endpoint);

allocator: *Allocator,
dir: [:0]const u8,
handleFn: Handle,

pub fn init(allocator: *Allocator, dir: [:0]const u8, handleFn: Handle) Endpoint {
    return Endpoint {
        .allocator = allocator,
        .dir = dir,
        .handleFn = handleFn,
    };
}

pub fn deinit(self: *Endpoint) void {
    
}

pub fn getInfo(filename_c: [*c]const u8, info: ?*c.UpnpFileInfo, cookie: ?*const c_void, request_cookie: [*c]?*const c_void) callconv(.C) c_int {
    var filename: []const u8 = undefined;
    filename.ptr = filename_c;
    filename.len = 0;
    while (filename_c[filename.len] != 0) : (filename.len += 1) {}

    const self = mutate(*Endpoint, cookie);
    var arena = Arena.init(self.allocator);
    if (self.handleFn(self, &arena.allocator, filename)) |response| {
        const request = arena.allocator.create(Request) catch {
            arena.deinit();
            return -1;
        };
        request.arena = arena;
        request.contents = response.contents;
        request.seek_pos = 0;
        request_cookie.* = request;

        _ = c.UpnpFileInfo_set_ContentType(info, response.content_type);
        _ = c.UpnpFileInfo_set_IsReadable(info, @boolToInt(response.is_readable));
        _ = c.UpnpFileInfo_set_FileLength(info, @intCast(c_long, response.contents.len));

        return 0;
    }

    arena.deinit();
    return -1;
}

pub fn open(filename_c: [*c]const u8, mode: c.enum_UpnpOpenFileMode, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c.UpnpWebFileHandle {
    if (mode != .UPNP_READ) {
        return null;
    }
    return undefined;
}

pub fn read(file_handle: c.UpnpWebFileHandle, buf: [*c]u8, buflen: usize, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    const request = mutate(*Request, request_cookie);
    const bytes_written = std.math.max(buflen, request.contents.len - request.seek_pos);
    std.mem.copy(u8, buf[0..buflen], request.contents[request.seek_pos..request.seek_pos + bytes_written]);
    return @intCast(c_int, bytes_written);
}

pub fn seek(file_handle: c.UpnpWebFileHandle, offset: c.off_t, origin: c_int, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    var request = mutate(*Request, request_cookie);
    request.seek_pos = @intCast(usize, offset + switch (origin) {
        c.SEEK_CUR => @intCast(c_long, request.seek_pos),
        c.SEEK_END => @intCast(c_long, request.contents.len),
        c.SEEK_SET => 0,
        else => return -1
    });
    return 0;
}

pub fn close(file_handle: c.UpnpWebFileHandle, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    var request = mutate(*Request, request_cookie);
    request.arena.deinit();
    return 0;
}

fn mutate(comptime T: type, ptr: ?*const c_void) T {
    return @intToPtr(T, @ptrToInt(ptr));
}
