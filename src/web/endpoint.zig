const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const c = @import("../c.zig");
const zupnp = @import("../main.zig");

pub const Response = struct {
    contents: []const u8,
    content_type: ?[]const u8 = null,
};

const Request = struct {
    response: Response,
    seek_pos: usize = 0,
};

const Endpoint = @This();

arena: Arena,
dir: [:0]const u8,
handleFn: fn (*Endpoint, []const u8) ?Response,

pub fn init(allocator: *std.mem.Allocator, dir: [:0]const u8) Endpoint {
    return Endpoint {
        .arena = Arena.init(allocator),
        .dir = dir,
    };
}

pub fn deinit(self: *Endpoint) void {
    self.arena.deinit();
}

pub fn getInfo(filename_c: [*c]const u8, info: ?*c.UpnpFileInfo, cookie: ?*const c_void, request_cookie: [*c]?*const c_void) callconv(.C) c_int {
    var filename: []const u8 = undefined;
    filename.ptr = filename_c;
    filename.len = 0;
    while (filename_c[filename.len] != 0) : (filename.len += 1) {}

    const self = mutate(*Endpoint, cookie);
    if (self.handleFn(self, filename)) |response| {
        const request = self.arena.allocator.create(Request) catch {
            self.arena.deinit();
            return -1;
        };
        request.response = response;
        request_cookie.* = request;
        return 0;
    }
    self.arena.deinit();
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
    const bytes_written = std.math.max(buflen, request.response.contents.len - request.seek_pos);
    std.mem.copy(u8, buf[0..request.seek_pos], request.response.contents[request.seek_pos..request.seek_pos + bytes_written]);
    return @intCast(c_int, bytes_written);
}

pub fn seek(file_handle: c.UpnpWebFileHandle, offset: c.off_t, origin: c_int, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    var request = mutate(*Request, request_cookie);
    request.seek_pos = @intCast(usize, offset + switch (origin) {
        c.SEEK_CUR => @intCast(c_long, request.seek_pos),
        c.SEEK_END => @intCast(c_long, request.response.contents.len),
        c.SEEK_SET => 0,
        else => return -1
    });
    return 0;
}

pub fn close(file_handle: c.UpnpWebFileHandle, cookie: ?*const c_void, request_cookie: ?*const c_void) callconv(.C) c_int {
    const self = mutate(*Endpoint, cookie);
    self.arena.deinit();
    return 0;
}

fn mutate(comptime T: type, ptr: ?*const c_void) T {
    return @intToPtr(T, @ptrToInt(ptr));
}
