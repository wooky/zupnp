const std = @import("std");
const testing = std.testing;
const zupnp = @import("zupnp");

test "simple requests" {
    const Endpoint = struct {
        const Self = @This();

        bogus: bool = true, // TODO remove me

        pub fn get(self: *Self, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            return zupnp.web.ServerResponse.contents(.{ .contents = "Hello", .content_type = "something/else" });
        }

        pub fn post(self: *Self, request: *const zupnp.web.ServerPostRequest) bool {
            return true;
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    defer lib.deinit();
    const dest = "/endpoint";
    _ = try lib.server.createEndpoint(Endpoint, {}, dest);
    try lib.server.start();
    var buf: [64]u8 = undefined;
    const url = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{lib.server.base_url, dest});

    {
        var response = try zupnp.web.request(.GET, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        try testing.expectEqualStrings("something/else", response.content_type.?);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("Hello", contents);
    }

    {
        var response = try zupnp.web.request(.POST, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("", contents);
    }

    {
        var response = try zupnp.web.request(.PUT, url, .{});
        try testing.expectEqual(@as(c_int, 501), response.http_status);
    }

    {
        var response = try zupnp.web.request(.DELETE, url, .{});
        try testing.expectEqual(@as(c_int, 500), response.http_status);
    }

    {
        var response = try zupnp.web.request(.HEAD, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        try testing.expectEqualStrings("something/else", response.content_type.?);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("", contents);
    }
}

test "chunked request" {
    const Endpoint = struct {
        const Self = @This();

        bogus: bool = true, // TODO remove me

        pub fn get(self: *Self, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            return zupnp.web.ServerResponse.contents(.{ .contents = "onetwothree", .content_type = "text/plain" });
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    defer lib.deinit();
    const dest = "/endpoint";
    _ = try lib.server.createEndpoint(Endpoint, {}, dest);
    try lib.server.start();
    var buf: [64]u8 = undefined;
    const url = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{lib.server.base_url, dest});

    var request = try zupnp.web.request(.GET, url, .{});
    try testing.expectEqual(@as(c_int, 200), request.http_status);
    try testing.expectEqualStrings("text/plain", request.content_type.?);
    try testing.expectEqual(@as(u32, 11), request.content_length.?);

    try testing.expectEqualStrings("one", (try request.readChunk(buf[0..3])).?);
    try testing.expectEqualStrings("two", (try request.readChunk(buf[0..3])).?);
    try testing.expectEqualStrings("three", (try request.readChunk(buf[0..5])).?);
    try testing.expectEqual(@as(?[]const u8, null), try request.readChunk(&buf));
}
