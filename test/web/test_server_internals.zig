const std = @import("std");
const testing = std.testing;
const zupnp = @import("zupnp");

const SUT = struct {
    const dest = "/endpoint";

    const Endpoint = struct {
        bogus: bool = true, // TODO remove me

        pub fn get(self: *Endpoint, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
            _ = request.allocator.alloc(u8, 1024) catch |e| @panic(@errorName(e));
            return zupnp.web.ServerResponse.contents(.{});
        }

        pub fn post(self: *Endpoint, request: *const zupnp.web.ServerPostRequest) bool {
            _ = request.allocator.alloc(u8, 1024) catch |e| @panic(@errorName(e));
            return true;
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

test "all requests clean up after themselves" {
    var sut = SUT {};
    try sut.init();
    defer sut.deinit();
    inline for (.{.GET, .HEAD, .POST}) |request| {
        var response = try zupnp.web.request(request, sut.url, .{});
        try testing.expectEqual(@as(c_int, 200), response.http_status);
    }
}
