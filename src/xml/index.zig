//! XML library.
//! You are encouraged to use the `Parser` and `Writer` to convert XML documents to and from structs, respectively.
//! You can also manually construct an XML document, starting with `Document`.

pub usingnamespace @import("xml.zig");
pub const DecodeResult = @import("parser.zig").DecodeResult;
pub const Error = error.XMLError;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn encode(allocator: *Allocator, input: anytype) !Document {
    var writer = @import("writer.zig").init(allocator);
    defer writer.deinit();
    return writer.writeStructToDocument(input);
}

pub fn decode(allocator: *Allocator, comptime T: type, doc: Document) !DecodeResult(T) {
    var parser = @import("parser.zig").init(allocator);
    errdefer parser.cleanup();
    return parser.parseDocument(T, doc);
}
