const std = @import("std");
const zupnp = @import("zupnp");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const logger = std.log.scoped(.Website);

pub fn main() !void {
    var lib = try zupnp.ZUPnP.init(std.heap.page_allocator, .{});
    defer lib.deinit();
    lib.server.static_root_dir = "static";
    _ = try lib.server.createEndpoint(Guestbook, .{ .allocator = std.heap.page_allocator }, "/guestbook");
    try lib.server.start();

    while (true) {
        std.time.sleep(1_000_000);
    }
}

const Guestbook = struct {
    const Config = struct {
        allocator: Allocator,
    };

    const Entry = struct {
        timestamp: i64 = undefined,
        name: []const u8,
        message: []const u8,
    };

    arena: ArenaAllocator,
    entries: std.ArrayList(Entry),

    pub fn prepare(self: *Guestbook, config: Config) !void {
        self.arena = ArenaAllocator.init(config.allocator);
        self.entries = std.ArrayList(Entry).init(self.arena.allocator());
    }

    pub fn deinit(self: *Guestbook) void {
        self.arena.deinit();
    }

    pub fn get(self: *Guestbook, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
        var buf = std.ArrayList(u8).init(request.allocator);
        std.json.stringify(self.entries.items, .{}, buf.writer()) catch |e| {
            logger.warn("{!}", .{e});
            return zupnp.web.ServerResponse.forbidden();
        };
        return zupnp.web.ServerResponse.contents(.{ .contents = buf.toOwnedSlice(), .content_type = "application/json" });
    }

    pub fn post(self: *Guestbook, request: *const zupnp.web.ServerPostRequest) bool {
        logger.debug("{s}", .{request.contents});
        var token_stream = std.json.TokenStream.init(request.contents);
        var entry = std.json.parse(Entry, &token_stream, .{ .allocator = self.arena.allocator() }) catch |e| {
            logger.warn("{!}", .{e});
            return false;
        };
        entry.timestamp = std.time.milliTimestamp();
        self.entries.insert(0, entry) catch return false;
        return true;
    }
};
