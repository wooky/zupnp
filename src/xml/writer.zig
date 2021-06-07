//! Converts any struct to an XML document.

const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const XML = @import("xml.zig");
const Error = error.XMLWriteError;

const XMLWriter = @This();
const logger = std.log.scoped(.XMLWriter);
usingnamespace @import("traverser.zig").XMLStructTraverser(XMLWriter, Error);

arena: ArenaAllocator,
doc: XML.Document = undefined,

pub fn init(allocator: *std.mem.Allocator) XMLWriter {
    return .{ .arena = ArenaAllocator.init(allocator) };
}

pub fn deinit(self: *XMLWriter) void {
    self.arena.deinit();
}

/// Convert a struct of your choosing to an XML document.
/// The resulting document is fully owned by the caller, so call `deinit()` on it when you're done with it.
pub fn writeStructToDocument(self: *XMLWriter, input: anytype) !XML.Document {
    self.doc = try XML.Document.new();
    try self.traverseStruct(&input, try self.doc.toNode());
    return self.doc;
}

pub fn handleSubStruct(self: *XMLWriter, comptime name: []const u8, input: anytype, parent: XML.Node) !void {
    var sub_parent = try self.doc.createElement(name ++ "\x00");
    try self.traverseStruct(input, try sub_parent.toNode());
    switch (parent) {
        .Document => |d| try d.appendChild(sub_parent),
        .Element => |e| try e.appendChild(sub_parent),
        else => {
            logger.warn("Invalid node type for node named {s}", .{name});
            return Error;
        }
    }
}

pub fn handlePointer(self: *XMLWriter, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    for (input.*) |subinput| {
        try self.traverseField(&subinput, name, try parent.toNode());
    }
}

pub fn handleOptional(self: *XMLWriter, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    if (input.*) |i| {
        try self.traverseField(&i, name, try parent.toNode());
    }
}

pub fn handleString(self: *XMLWriter, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    var node = try self.doc.createElement(name ++ "\x00");
    var text = try self.doc.createTextNode(try self.arena.allocator.dupeZ(u8, input.*));
    try node.appendChild(text);
    try parent.appendChild(node);
}

pub fn handleAttributes(self: *XMLWriter, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
        const field_value_opt: ?[]const u8 = @field(input.*, field.name);
        if (field_value_opt) |field_value| {
            try parent.setAttribute(field.name ++ "\x00", try self.arena.allocator.dupeZ(u8, field_value));
        }
    }
}
