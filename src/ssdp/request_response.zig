const std = @import("std");
const Allocator = std.mem.Allocator;
const Headers = std.StringHashMap([]const u8);

pub const Request = struct {
    const logger = std.log.scoped(.@"zupnp.ssdp.Request");

    method: []const u8,
    headers: Headers,

    pub fn init(allocator: Allocator, method: []const u8) Request {
        return Request {
            .method = method,
            .headers = Headers.init(allocator),
        };
    }

    pub fn parse(allocator: Allocator, reader: anytype) !?Request {
        const req_str = reader.readAllAlloc(allocator, 1024);
        defer allocator.free(req_str);
        var lines = std.mem.tokenize(u8, req_str, "\r\n");

        const method = blk: {
            const line = lines.next() orelse {
                logger.err("parse error: missing request line", .{});
                return error.ParseError;
            };
            var tokens = std.mem.tokenize(u8, line, " ");
            const method = tokens.next() orelse {
                logger.err("parse error: missing method", .{});
                return error.ParseError;
            };
            // We assume that everything else on this line is OK

            break :blk method; // TODO uhh this should be cloned
        };

        var headers = Headers.init(allocator);
        errdefer headers.deinit();
        var received_host = false;
        while (lines.next()) |line| {
            const separator = std.mem.indexOfScalar(u8, line, ':') orelse {
                logger.err("parse error: invalid header");
                return error.ParseError;
            };
            const key = std.mem.trim(u8, line[0..separator], std.ascii.spaces);
            const value = std.mem.trim(u8, line[separator + 1..], std.ascii.spaces);

            if (std.ascii.eqlIgnoreCase(key, "HOST")) {
                if (!std.mem.startsWith(u8, value, "239.255.255.250")) {
                    logger.debug("request host is not for us, skipping", .{});
                    return null;
                }
                if (std.mem.indexOfScalar(u8, value, ':')) |delim| {
                    if (!std.mem.eql(u8, value[delim..], ":1900")) {
                        logger.debug("request port is not for us, skipping", .{});
                        return null;
                    }
                }
                received_host = true;
            }

            if (!received_host) {
                logger.err("parse error: HOST header was not received");
                return error.ParseError;
            }

            try headers.put(key, value);
        }

        return Request {
            .method = method,
            .headers = headers,
        };
    }

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
    }

    pub fn write(self: *Request, writer: anytype) !void {
        try self.headers.put("HOST", "239.255.255.250");
        try writer.print("{} * HTTP/1.1", .{self.method});
        var iter = self.headers.iterator();
        while (iter.next()) |kv| {
            try writer.print("{}: {}\r\n", .{kv.key_ptr.*, kv.value_ptr.*});
        }
    }
};

pub const Response = struct {
    headers: Headers,

    pub fn init(allocator: Allocator) Response {
        return Response {
            .headers = Headers.init(allocator),
        };
    }

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
    }

    pub fn write(self: *Response, writer: anytype) !void {
        try writer.writeAll("HTTP/1.1 200 OK\r\n");
        var iter = self.headers.iterator();
        while (iter.next()) |kv| {
            try writer.print("{}: {}\r\n", .{kv.key_ptr.*, kv.value_ptr.*});
        }
    }
};
