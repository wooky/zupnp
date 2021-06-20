const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const xml = @import("../lib.zig").xml;

const Writer = @This();
const logger = std.log.scoped(.@"zupnp.xml.Writer");
usingnamespace @import("traverser.zig").StructTraverser(Writer, logger);

arena: ArenaAllocator,
doc: xml.Document = undefined,

pub fn init(allocator: *std.mem.Allocator) Writer {
    return .{ .arena = ArenaAllocator.init(allocator) };
}

pub fn deinit(self: *Writer) void {
    self.arena.deinit();
}

pub fn writeStructToDocument(self: *Writer, input: anytype) !xml.Document {
    self.doc = try xml.Document.new();
    try self.traverseStruct(&input, try self.doc.toNode());
    return self.doc;
}

pub fn handleSubStruct(self: *Writer, comptime name: []const u8, input: anytype, parent: xml.Node) !void {
    var sub_parent = try self.doc.createElement(name ++ "\x00");
    try self.traverseStruct(input, try sub_parent.toNode());
    switch (parent) {
        .Document => |d| try d.appendChild(sub_parent),
        .Element => |e| try e.appendChild(sub_parent),
        else => {
            logger.warn("Invalid node type for node named {s}", .{name});
            return xml.Error;
        }
    }
}

pub fn handlePointer(self: *Writer, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    for (input.*) |subinput| {
        try self.traverseField(&subinput, name, try parent.toNode());
    }
}

pub fn handleOptional(self: *Writer, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    if (input.*) |i| {
        try self.traverseField(&i, name, try parent.toNode());
    }
}

pub fn handleString(self: *Writer, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    var node = try self.doc.createElement(name ++ "\x00");
    var text = try self.doc.createTextNode(try self.arena.allocator.dupeZ(u8, input.*));
    try node.appendChild(text);
    try parent.appendChild(node);
}

pub fn handleAttributes(self: *Writer, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
        const field_value_opt: ?[]const u8 = @field(input.*, field.name);
        if (field_value_opt) |field_value| {
            try parent.setAttribute(field.name ++ "\x00", try self.arena.allocator.dupeZ(u8, field_value));
        }
    }
}
