const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const XML = @import("xml.zig");
const Error = error.XMLParseError;

const XMLParser = @This();
const logger = std.log.scoped(.XMLParser);
usingnamespace @import("traverser.zig").XMLStructTraverser(XMLParser, Error);

arena: ArenaAllocator,

pub fn init(allocator: *std.mem.Allocator) XMLParser {
    return .{ .arena = ArenaAllocator.init(allocator) };
}

pub fn deinit(self: *XMLParser) void {
    self.arena.deinit();
}

pub fn parseDocument(self: *XMLParser, comptime T: type, doc: XML.Document) !*T {
    var result = try self.arena.allocator.create(T);
    try self.traverseStruct(result, try doc.toNode());
    return result;
}

pub fn handleSubStruct(self: *XMLParser, comptime name: []const u8, input: anytype, parent: XML.Node) !void {
    var child = switch (parent) {
        .Document => |d| d.getElementsByTagName(name ++ "\x00"),
        .Element => |e| e.getElementsByTagName(name ++ "\x00"),
        else => {
            logger.warn("Invalid type for node named {}", .{name});
            return Error;
        }
    }.getSingleItem() catch {
        logger.warn("Missing element {}", .{name});
        return Error;
    };
    try self.traverseStruct(input, child);
}

pub fn handlePointer(self: *XMLParser, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    const PointerChild = @typeInfo(@TypeOf(input.*)).Pointer.child;
    var iterator = parent.getElementsByTagName(name ++ "\x00").iterator();
    if (iterator.length > 0) {
        var resultants = try self.arena.allocator.alloc(PointerChild, iterator.length);
        for (resultants) |*res, idx| {
            try self.traverseField(res, name, (try iterator.next()).?);
        }
        input.* = resultants;
    }
    else {
        input.* = &[_]PointerChild {};
    }
}

pub fn handleOptional(self: *XMLParser, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    const list = parent.getElementsByTagName(name ++ "\x00");
    switch (list.getLength()) {
        1 => {
            var subopt: @typeInfo(@TypeOf(input.*)).Optional.child = undefined;
            try self.traverseField(&subopt, name, try list.getSingleItem());
            input.* = subopt;
        },
        0 => input.* = null,
        else => |l| {
            logger.warn("Expecting 0 or 1 {} elements, found {}", .{name, l});
            return Error;
        }
    }
}

pub fn handleString(self: *XMLParser, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    var element = parent.getElementsByTagName(name ++ "\x00").getSingleItem() catch {
        logger.warn("Missing element {}", .{name});
        return Error;
    };
    var text_node = (try element.Element.getFirstChild()) orelse {
        logger.warn("Text element {} has no text", .{name});
        return Error;
    };
    switch (text_node) {
        .TextNode => |tn| input.* = try self.arena.allocator.dupe(u8, tn.getValue()),
        else => {
            logger.warn("Element {} is not a text element", .{name});
            return Error;
        }
    }
}

pub fn handleAttributes(self: *XMLParser, comptime name: []const u8, input: anytype, parent: XML.Element) !void {
    var attributes = parent.getAttributes();
    inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
        const value = blk: {
            var node = attributes.getNamedItem(field.name ++ "\x00") orelse break :blk null;
            break :blk try self.arena.allocator.dupe(u8, node.getValue());
        };
        @field(input, field.name) = switch (field.field_type) {
            ?[]const u8, ?[]u8 => value,
            []const u8, []u8 => value orelse return Error,
            else => @compileError("Invalid field '" ++ field.name ++ "' for attribute struct")
        };
    }
}
