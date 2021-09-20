const std = @import("std");
const testing = std.testing;
const zupnp = @import("zupnp");

test "simple requests" {
    const Endpoint = struct {
        const Self = @This();

        bogus: bool = true, // TODO remove me

        pub fn get(self: *Self, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            return .{ .Contents = .{ .contents = "Hello", .content_type = "something/else" } };
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
    var client = zupnp.web.Client.init();
    defer client.deinit();
    var buf: [64]u8 = undefined;
    const url = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{lib.server.base_url, dest});

    {
        var response = try client.request(.GET, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        try testing.expectEqualStrings("something/else", response.content_type.?);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("Hello", contents);
    }

    {
        var response = try client.request(.POST, url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
        const contents = try response.readAll(testing.allocator);
        defer testing.allocator.free(contents);
        try testing.expectEqualStrings("", contents);
    }

    {
        var response = try client.request(.PUT, url, .{});
        try testing.expectEqual(@as(c_int, 501), response.http_status);
    }

    {
        var response = try client.request(.DELETE, url, .{});
        try testing.expectEqual(@as(c_int, 500), response.http_status);
    }

    {
        var response = try client.request(.HEAD, url, .{});
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
            return .{ .Contents = .{ .contents = "onetwothree", .content_type = "text/plain" } };
        }
    };

    var lib = try zupnp.ZUPnP.init(testing.allocator, .{});
    defer lib.deinit();
    const dest = "/endpoint";
    _ = try lib.server.createEndpoint(Endpoint, {}, dest);
    try lib.server.start();
    var client = zupnp.web.Client.init();
    defer client.deinit();
    var buf: [64]u8 = undefined;
    const url = try std.fmt.bufPrintZ(&buf, "{s}{s}", .{lib.server.base_url, dest});

    var request = try client.request(.GET, url, .{});
    try testing.expectEqual(@as(c_int, 200), request.http_status);
    try testing.expectEqualStrings("text/plain", request.content_type.?);
    try testing.expectEqual(@as(u32, 11), request.content_length.?);

    try testing.expectEqualStrings("one", (try request.readChunk(buf[0..3])).?);
    try testing.expectEqualStrings("two", (try request.readChunk(buf[0..3])).?);
    try testing.expectEqualStrings("three", (try request.readChunk(buf[0..5])).?);
    try testing.expectEqual(@as(?[]const u8, null), try request.readChunk(&buf));
}
