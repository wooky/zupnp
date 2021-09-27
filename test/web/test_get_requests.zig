const std = @import("std");
const testing = std.testing;
const zupnp = @import("zupnp");

const SUT = struct {
    const one = "one";
    const two = "two";
    const three = "three";
    const contents = one ++ two ++ three;
    const content_type = "test/whatever";
    const dest = "/endpoint";

    const Endpoint = struct {
        bogus: bool = true, // TODO remove me

        pub fn get(self: *Endpoint, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            return zupnp.web.ServerResponse.contents(.{ .contents = contents, .content_type = content_type });
        }
    };

    lib: zupnp.ZUPnP = undefined,
    url: [:0]const u8 = undefined,

    fn init(self: *SUT) !void {
        self.lib = try zupnp.ZUPnP.init(testing.allocator, .{});
        _ = try self.lib.server.createEndpoint(Endpoint, {}, dest);
        try self.lib.server.start();
        self.url = try std.fmt.allocPrintZ(testing.allocator, "{s}{s}", .{self.lib.server.base_url, dest});
    }

    fn deinit(self: *SUT) void {
        testing.allocator.free(self.url);
        self.lib.deinit();
    }
};

test "GET request returns code 200 with contents" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    var response = try zupnp.web.request(.GET, sut.url, .{});
    try testing.expectEqual(@as(c_int, 200), response.http_status);
    try testing.expectEqualStrings(SUT.content_type, response.content_type.?);
    const contents = try response.readAll(testing.allocator);
    defer testing.allocator.free(contents);
    try testing.expectEqualStrings(SUT.contents, contents);
}

test "HEAD request returns code 200 with no contents" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    var response = try zupnp.web.request(.HEAD, sut.url, .{});
    try testing.expectEqual(@as(c_int, 200), response.http_status);
    try testing.expectEqualStrings(SUT.content_type, response.content_type.?);
    const contents = try response.readAll(testing.allocator);
    defer testing.allocator.free(contents);
    try testing.expectEqualStrings("", contents);
}

test "unhandled requests return server error codes" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    inline for (.{
        .{.POST, 500},
        .{.PUT, 501},
        .{.DELETE, 500}
    }) |requestAndCode| {
        var response = try zupnp.web.request(requestAndCode.@"0", sut.url, .{});
        try testing.expectEqual(@as(c_int, requestAndCode.@"1"), response.http_status);
    }
}

test "GET request with chunks gets individual parts of contents" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    var request = try zupnp.web.request(.GET, sut.url, .{});
    try testing.expectEqual(@as(c_int, 200), request.http_status);
    try testing.expectEqualStrings(SUT.content_type, request.content_type.?);
    try testing.expectEqual(@as(u32, SUT.contents.len), request.content_length.?);

    var buf: [8]u8 = undefined;
    inline for (.{SUT.one, SUT.two, SUT.three}) |part| {
        try testing.expectEqualStrings(part, (try request.readChunk(buf[0..part.len])).?);
    }
    try testing.expectEqual(@as(?[]const u8, null), try request.readChunk(&buf));
}
