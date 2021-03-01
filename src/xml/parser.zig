const c = @import("../c.zig");
const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const Error = error.XMLParseError;

const XMLParser = @This();
const logger = std.log.scoped(.XMLParser);
usingnamespace @import("traverser.zig").XMLStructTraverser(XMLParser);

arena: ArenaAllocator,

pub fn init(allocator: *std.mem.Allocator) XMLParser {
    return .{ .arena = ArenaAllocator.init(allocator) };
}

pub fn deinit(self: *XMLParser) void {
    self.arena.deinit();
}

pub fn parseDocumentFromString(self: *XMLParser, comptime T: type, document: [:0]const u8) !*T {
    var handle: [*c]c.IXML_Document = undefined;
    const err = c.ixmlParseBufferEx(document, &handle);
    if (err == c.IXML_SUCCESS) {
        defer c.ixmlDocument_free(handle);
        return self.parseDocumentFromHandle(T, handle);
    }
    else {
        logger.warn("Failed to parse XML string: {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
        return Error;
    }
}

pub fn parseDocumentFromHandle(self: *XMLParser, comptime T: type, handle: *c.IXML_Document) !*T {
    var result = try self.arena.allocator.create(T);
    try self.traverseStruct(result, @ptrCast(*c.IXML_Node, handle));
    return result;
}

pub fn precheckNode(self: *XMLParser, node: *c.IXML_Node) !void {
    const node_type = c.ixmlNode_getNodeType(node);
    if (node_type != c.eELEMENT_NODE and node_type != c.eDOCUMENT_NODE) {
        logger.warn("Node was expected to be an element, but is {}", .{@intToEnum(c.IXML_NODE_TYPE, node_type)});
        return Error;
    }
}

pub fn handleSubStruct(self: *XMLParser, comptime name: []const u8, input: anytype, parent: *c.IXML_Node) !void {
    if (try getSingleElement(parent, name)) |child| {
        try self.traverseStruct(input, child);
    }
    else {
        logger.warn("Missing element {}", .{name});
        return error.XMLParseError;
    }
}

pub fn handlePointer(self: *XMLParser, comptime name: []const u8, input: anytype, parent: *c.IXML_Node) !void {
    const PointerChild = @typeInfo(@TypeOf(input.*)).Pointer.child;
    if (c.ixmlElement_getElementsByTagName(@ptrCast(*c.IXML_Element, parent), name ++ "\x00")) |elements| {
        const count = c.ixmlNodeList_length(elements);
        var resultants = try self.arena.allocator.alloc(PointerChild, count);
        for (resultants) |*res, idx| {
            const child = c.ixmlNodeList_item(elements, idx) orelse return error.XMLParseError;
            try self.traverseField(res, name, child);
        }
        input.* = resultants;
    }
    else {
        input.* = &[_]PointerChild {};
    }
}

pub fn handleOptional(self: *XMLParser, comptime name: []const u8, input: anytype, parent: *c.IXML_Node) !void {
    if (try getSingleElement(parent, name)) |child| {
        var subopt: @typeInfo(@TypeOf(input.*)).Optional.child = undefined;
        try self.traverseField(&subopt, name, child);
        input.* = subopt;
    }
    else {
        input.* = null;
    }
}

pub fn handleString(self: *XMLParser, comptime name: []const u8, input: anytype, parent: *c.IXML_Node) !void {
    const element = (try getSingleElement(parent, name)) orelse {
        logger.warn("Missing element {}", .{name});
        return error.XMLParseError;
    };
    const text_node = c.ixmlNode_getFirstChild(element) orelse {
        logger.warn("Text element {} has no text", .{name});
        return error.XMLParseError;
    };
    if (c.ixmlNode_getNodeType(text_node) != c.eTEXT_NODE) {
        logger.warn("Element {} is not a text element", .{name});
        return error.XMLParseError;
    }
    input.* = try self.cloneCString(c.ixmlNode_getNodeValue(text_node));
}

pub fn handleAttributes(self: *XMLParser, comptime name: []const u8, input: anytype, parent: *c.IXML_Node) !void {
    const attributes = c.ixmlNode_getAttributes(parent) orelse {
        logger.err("Failed to get attributes for element {}", .{name});
        return error.XMLParseError;
    };
    inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
        const value = blk: {
            const node = c.ixmlNamedNodeMap_getNamedItem(attributes, field.name ++ "\x00") orelse break :blk null;
            const raw_value = c.ixmlNode_getNodeValue(node) orelse return Error;
            break :blk try self.cloneCString(raw_value);
        };
        @field(input, field.name) = switch (field.field_type) {
            ?[]const u8, ?[]u8 => value,
            []const u8, []u8 => value orelse return Error,
            else => @compileError("Invalid field '" ++ field.name ++ "' for attribute struct")
        };
    }
}

fn getSingleElement(parent: *c.IXML_Node, comptime child: []const u8) !?*c.IXML_Node {
    const elements = c.ixmlElement_getElementsByTagName(@ptrCast(*c.IXML_Element, parent), child ++ "\x00") orelse return null;
    const count = c.ixmlNodeList_length(elements);
    if (count > 1) {
        return Error;
    }
    return c.ixmlNodeList_item(elements, 0) orelse Error;
}

fn cloneCString(self: *XMLParser, str: [*c]const u8) ![]u8 {
    var slice: []const u8 = undefined;
    slice.ptr = str;
    slice.len = 0;
    while (str[slice.len] != 0) : (slice.len += 1) {}
    return self.arena.allocator.dupe(u8, slice);
}
