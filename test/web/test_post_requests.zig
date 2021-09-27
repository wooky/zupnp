const std = @import("std");
const testing = std.testing;
const zupnp = @import("zupnp");

const SUT = struct {
    const dest = "/endpoint";

    const Endpoint = struct {
        last_message: []const u8,

        pub fn prepare(self: *Endpoint, config: void) !void {
            self.last_message = try testing.allocator.alloc(u8, 0);
        }

        pub fn deinit(self: *Endpoint) void {
            testing.allocator.free(self.last_message);
        }

        pub fn post(self: *Endpoint, request: *const zupnp.web.ServerPostRequest) bool {
            testing.allocator.free(self.last_message);
            self.last_message = testing.allocator.dupe(u8, request.contents) catch |e| @panic(@errorName(e));
            return true;
        }
    };

    lib: zupnp.ZUPnP = undefined,
    endpoint: *Endpoint = undefined,
    url: [:0]const u8 = undefined,

    fn init(self: *SUT) !void {
        self.lib = try zupnp.ZUPnP.init(testing.allocator, .{});
        self.endpoint = try self.lib.server.createEndpoint(Endpoint, {}, dest);
        try self.lib.server.start();
        self.url = try std.fmt.allocPrintZ(testing.allocator, "{s}{s}", .{self.lib.server.base_url, dest});
    }

    fn deinit(self: *SUT) void {
        testing.allocator.free(self.url);
        self.lib.deinit();
    }
};

test "POST request stores contents and returns code 200 with no contents" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    const contents = "Hello world!";
    var response = try zupnp.web.request(.POST, sut.url, .{ .contents = contents });
    try testing.expectEqual(@as(c_int, 200), response.http_status);
    try testing.expectEqualStrings(contents, sut.endpoint.last_message);
}

test "unhandled requests return server error codes" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    inline for (.{
        .{.GET, 404},
        .{.HEAD, 404},
        .{.PUT, 501},
        .{.DELETE, 500}
    }) |requestAndCode| {
        var response = try zupnp.web.request(requestAndCode.@"0", sut.url, .{});
        try testing.expectEqual(@as(c_int, requestAndCode.@"1"), response.http_status);
    }
}
