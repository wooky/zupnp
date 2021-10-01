const std = @import("std");
const c = @import("../c.zig");
const Allocator = std.mem.Allocator;

const Headers = @This();
const HeaderItems = std.StringHashMap([:0]const u8);
const logger = std.log.scoped(.@"zupnp.web.Headers");

const ExtraHeadersIterator = struct {
    header_list: ?*c.UpnpListHead,
    pos: c.UpnpListIter,

    fn init(header_list: ?*c.UpnpListHead) ExtraHeadersIterator {
        return .{
            .header_list = header_list,
            .pos = if (header_list) |hl| @ptrCast(c.UpnpListIter, hl) else undefined,
        };
    }

    fn next(self: *ExtraHeadersIterator) ?*c.UpnpExtraHeaders {
        if (self.header_list == null or self.pos == c.UpnpListEnd(self.header_list, self.pos)) {
            return null;
        }

        var res = @ptrCast(*c.UpnpExtraHeaders, self.pos);
        self.pos = c.UpnpListNext(self.header_list, self.pos);
        return res;
    }
};

allocator: *Allocator,
items: HeaderItems,

pub fn init(allocator: *Allocator) Headers {
    return .{
        .allocator = allocator,
        .items = HeaderItems.init(allocator),
    };
}

pub fn fromHeaderList(allocator: *Allocator, header_list: ?*c.UpnpListHead) !Headers {
    var items = HeaderItems.init(allocator);
    errdefer items.deinit();
    var iter = ExtraHeadersIterator.init(header_list);
    while (iter.next()) {
        try items.put(
            c.UpnpExtraHeaders_get_name_cstr[0..c.UpnpExtraHeaders_get_name_Length],
            c.UpnpExtraHeaders_get_value_cstr[0..c.UpnpExtraHeaders_get_value_Length]
        );
    }
    return Headers {
        .items = items,
    };
}

pub fn deinit(self: *Headers) void {
    self.items.deinit();
}

pub fn addHeadersToList(self: *const Headers, list: *const c.UpnpListHead) !void {
    var mut_list = c.mutate(*c.UpnpListHead, list);
    var last: ?*c.UpnpExtraHeaders = null;
    var iter = self.items.iterator();
    while (iter.next()) |kv| {
        var header_str_tmp = try std.fmt.allocPrintZ(self.allocator, "{s}: {s}", .{kv.key_ptr.*, kv.value_ptr.*});
        defer self.allocator.free(header_str_tmp);
        var header = c.UpnpExtraHeaders_new();
        logger.debug("resp err {d}", .{
            c.UpnpExtraHeaders_set_resp(header, c.ixmlCloneDOMString(header_str_tmp)),
        });
        if (last) |l| {
            c.UpnpExtraHeaders_add_to_list_node(last, c.mutate(*c.UpnpListHead, c.UpnpExtraHeaders_get_node(header)));
        }
        last = header;
    }
    if (last) |l| {
        c.UpnpExtraHeaders_add_to_list_node(l, mut_list);
    }
}

pub fn toString(self: *const Headers) !std.ArrayList(u8) {
    const CRLF = "\r\n";
    var buf = std.ArrayList(u8).init(self.allocator);
    errdefer buf.deinit();
    var iter = self.items.iterator();
    while (iter.next()) |kv| {
        try buf.appendSlice(kv.key_ptr.*);
        try buf.appendSlice(": ");
        try buf.appendSlice(kv.value_ptr.*);
        try buf.appendSlice(CRLF);
    }
    buf.shrinkRetainingCapacity(buf.items.len - CRLF.len); // trim excess CRLF
    return buf;
}
