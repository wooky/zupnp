const std = @import("std");
const testing = std.testing;
const zupnp = @import("zupnp");

test "endpoint prepare and deinit" {
    var deinit = false;

    const DummyEndpoint = struct {
        const Config = struct {
            string: []const u8,
            number: u4,
            deinit_ptr: *bool,
        };
        const Self = @This();

        string: []const u8,
        number: u4,
        deinit_ptr: *bool,

        pub fn prepare(self: *Self, config: Config) !void {
            self.string = config.string;
            self.number = config.number;
            self.deinit_ptr = config.deinit_ptr;
        }

        pub fn deinit(self: *Self) void {
            self.deinit_ptr.* = true;
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    const endpoint = try lib.server.createEndpoint(
        DummyEndpoint,
        .{ .string = "a string", .number = 5, .deinit_ptr = &deinit },
        "/bogus"
    );
    try testing.expectEqualStrings("a string", endpoint.string);
    try testing.expectEqual(@as(u4, 5), endpoint.number);

    lib.deinit();
    try testing.expect(deinit);
}

test "GET endpoint" {
    const GetEndpoint = struct {
        const Self = @This();

        bogus: bool = true, // TODO remove me

        pub fn get(self: *Self, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            const action = request.filename[std.mem.lastIndexOf(u8, request.filename, "/").? + 1 ..];
            if (std.mem.eql(u8, action, "NotFound")) {
                return zupnp.web.ServerResponse.notFound();
            }
            if (std.mem.eql(u8, action, "Forbidden")) {
                return zupnp.web.ServerResponse.forbidden();
            }
            const contents = std.fmt.allocPrint(request.allocator, "Hello {s}", .{action}) catch |e| @panic(@errorName(e));
            return zupnp.web.ServerResponse.contents(.{ .contents = contents, .content_type = "text/plain" }); // TODO remove content type once the client stops crashing
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    defer lib.deinit();
    const dest = "/get";
    _ = try lib.server.createEndpoint(GetEndpoint, {}, dest);
    try lib.server.start();
    var buf: [64]u8 = undefined;

    {
        const url = try std.fmt.bufPrintZ(&buf, "{s}{s}/NotFound", .{lib.server.base_url.?, dest});
        var response = try zupnp.web.request(.GET, url, .{});
        try testing.expectEqual(@as(c_int, 404), response.http_status);
    }

    {
        const url = try std.fmt.bufPrintZ(&buf, "{s}{s}/Forbidden", .{lib.server.base_url.?, dest});
        var response = try zupnp.web.request(.GET, url, .{});
        try testing.expectEqual(@as(c_int, 403), response.http_status);
    }

    {
        const url = try std.fmt.bufPrintZ(&buf, "{s}{s}/world!", .{lib.server.base_url.?, dest});
        var response = try zupnp.web.request(.GET, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("Hello world!", contents);
    }
}

test "GET/POST endpoint" {
    const GetPostEndpoint = struct {
        const Self = @This();

        last_message: []const u8,

        pub fn prepare(self: *Self, config: void) !void {
            self.last_message = try std.fmt.allocPrint(testing.allocator, "no message", .{});
        }

        pub fn deinit(self: *Self) void {
            testing.allocator.free(self.last_message);
        }

        pub fn get(self: *Self, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            return zupnp.web.ServerResponse.contents(.{ .contents = self.last_message, .content_type = "text/plain" }); // TODO remove content type once the client stops crashing
        }

        pub fn post(self: *Self, request: *const zupnp.web.ServerPostRequest) bool {
            testing.allocator.free(self.last_message);
            self.last_message = testing.allocator.dupe(u8, request.contents) catch |e| @panic(@errorName(e));
            return true;
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    defer lib.deinit();
    const dest = "/get-post";
    _ = try lib.server.createEndpoint(GetPostEndpoint, {}, dest);
    try lib.server.start();
    var buf: [64]u8 = undefined;
    const url = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{lib.server.base_url, dest});

    {
        var response = try zupnp.web.request(.GET, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("no message", contents);
    }

    {
        var response = try zupnp.web.request(.POST, url, .{ .contents = "Hello world!" });
        try testing.expectEqual(@as(c_int, 200), response.http_status);
    }

    {
        var response = try zupnp.web.request(.GET, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("Hello world!", contents);
    }
}

test "HEAD requests cleans up after itself" {
    const GetEndpoint = struct {
        const Self = @This();

        bogus: bool = true, // TODO remove me

        pub fn get(self: *Self, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            _ = request.allocator.alloc(u8, 1024) catch |e| @panic(@errorName(e));
            return zupnp.web.ServerResponse.contents(.{ .contents = "whatever", .content_type = "text/plain" }); // TODO remove content type once the client stops crashing
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    defer lib.deinit();
    const dest = "/get";
    _ = try lib.server.createEndpoint(GetEndpoint, {}, dest);
    try lib.server.start();
    var buf: [64]u8 = undefined;
    const url = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{lib.server.base_url, dest});

    {
        var response = try zupnp.web.request(.HEAD, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("", contents);
    }
}

test "chunked response" {
    const ChunkGenerator = struct {
        const Self = @This();

        bogus: bool = true, // TODO remove me

        pub fn getChunk(self: *Self, buf: []u8, offset: usize) usize {
            var idx: usize = 0;
            var i = offset;
            while (idx < buf.len) {
                const number = std.fmt.bufPrint(buf[idx..], "{d}", .{i}) catch |e| @panic(@errorName(e));
                idx += number.len;
                i += 1;
            }
            return idx;
        }
    };

    const GetEndpoint = struct {
        const Self = @This();

        bogus: bool = true, // TODO remove me

        pub fn get(self: *Self, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            const generator = request.allocator.create(ChunkGenerator) catch |e| @panic(@errorName(e));
            return zupnp.web.ServerResponse.chunked(.{ .content_type = "text/plain" }, generator); // TODO remove content type once the client stops crashing
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    defer lib.deinit();
    const dest = "/chunk";
    _ = try lib.server.createEndpoint(GetEndpoint, {}, dest);
    try lib.server.start();
    var buf: [64]u8 = undefined;
    const url = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{lib.server.base_url, dest});

    var response = try zupnp.web.request(.GET, url, .{});
    defer response.cancel(); // Careful!
    try testing.expectEqual(@as(c_int, 200), response.http_status);
    try testing.expectEqual(@as(?u32, null), response.content_length);

    {
        var contents_buf: [1]u8 = undefined;
        const contents = try response.readChunk(&contents_buf);
        try testing.expectEqualStrings("0", contents.?);
    }

    {
        var contents_buf: [8]u8 = undefined;
        const contents = try response.readChunk(&contents_buf);
        try testing.expectEqualStrings("12345678", contents.?);
    }

    {
        var contents_buf: [43]u8 = undefined;
        const contents = try response.readChunk(&contents_buf);
        try testing.expectEqualStrings("9101112131415161718192021222324252627282930", contents.?);
    }
}
