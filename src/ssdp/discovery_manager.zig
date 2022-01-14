const std = @import("std");
const zupnp = @import("../lib.zig");
const Allocator = std.mem.Allocator;

const logger = std.log.scoped(.@"zupnp.ssdp.DiscoveryManager");

pub fn DiscoveryManager(writer: anytype) type {
    return struct {
        const Self = @This();

        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
            };
        }

        pub fn accept(self: *Self, request: zupnp.ssdp.Request) !void {
            if (std.ascii.eqlIgnoreCase(request.method, "M-SEARCH")) {
                return self.processSearchRequest(request);
            }

            logger.err("Received SSDP request with invalid header {}", .{request.method});
            return error.InvalidRequest;
        }

        pub fn sendAdvertiseAvailable(self: *Self) !void {

        }

        pub fn sendAdvertiseUnavailable(self: *Self) !void {

        }

        pub fn sendSearchRequest(self: *Self) !void {

        }

        pub fn sendSearchResponse(self: *Self) !void {

        }

        pub fn processSearchRequest(self: *Self, request: zupnp.ssdp.Request) !void {

        }
    };
}
