const std = @import("std");
const testing = std.testing;
const zupnp = @import("zupnp");

const SUT = struct {
    const not_found = "NotFound";
    const forbidden = "Forbidden";
    const dest = "/endpoint";

    const Endpoint = struct {
        pub fn get(request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            const action = request.filename[std.mem.lastIndexOf(u8, request.filename, "/").? + 1 ..];
            if (std.mem.eql(u8, action, not_found)) {
                return zupnp.web.ServerResponse.notFound();
            }
            if (std.mem.eql(u8, action, forbidden)) {
                return zupnp.web.ServerResponse.forbidden();
            }
            const contents = std.fmt.allocPrint(request.allocator, "Hello {s}", .{action}) catch |e| @panic(@errorName(e));
            return zupnp.web.ServerResponse.contents(.{ .contents = contents });
        }
    };

    lib: zupnp.ZUPnP = undefined,
    url: [:0]const u8 = undefined,

    fn init(self: *SUT) !void {
        self.lib = try zupnp.ZUPnP.init(testing.allocator, .{});
        _ = try self.lib.server.createEndpoint(Endpoint, {}, dest);
        try self.lib.server.start();
        self.url = try std.fmt.allocPrintZ(testing.allocator, "{s}{s}", .{self.lib.server.base_url.?, dest});
    }

    fn deinit(self: *SUT) void {
        testing.allocator.free(self.url);
        self.lib.deinit();
    }

    fn get(self: *SUT, contents: []const u8) !zupnp.web.ClientResponse {
        const url = try std.fmt.allocPrintZ(testing.allocator, "{s}{s}/{s}", .{self.lib.server.base_url.?, SUT.dest, contents});
        defer testing.allocator.free(url);
        return try zupnp.web.request(.GET, url, .{});
    }
};

test "return code 404" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    var response = try sut.get(SUT.not_found);
    try testing.expectEqual(@as(c_int, 404), response.http_status);
}

test "return code 403" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    var response = try sut.get(SUT.forbidden);
    try testing.expectEqual(@as(c_int, 403), response.http_status);
}

test "return custom contents" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    var response = try sut.get("world!");
    try testing.expectEqual(@as(c_int, 200), response.http_status);
    const contents = try response.readAll(testing.allocator);
    defer testing.allocator.free(contents);
    try testing.expectEqualStrings("Hello world!", contents);
}
