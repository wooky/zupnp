const c = @import("../c.zig");
const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const Error = error.XMLParseError;

const XMLParser = @This();
const logger = std.log.scoped(.XMLParser);
const attributes_field_name = "__attributes__";

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
    result.* = try self.populateStruct(T, @ptrCast(*c.IXML_Node, handle));
    return result;
}

fn populateStruct(self: *XMLParser, comptime T: type, node: *c.IXML_Node) !T {
    const node_type = c.ixmlNode_getNodeType(node);
    if (node_type != c.eELEMENT_NODE and node_type != c.eDOCUMENT_NODE) {
        logger.warn("Node was expected to be an element, but is {}", .{@intToEnum(c.IXML_NODE_TYPE, node_type)});
        return Error;
    }
    const element = @ptrCast(*c.IXML_Element, node);

    var result = T {};
    inline for (@typeInfo(T).Struct.fields) |field| {
        @field(result, field.name) = switch (field.field_type) {
            ?[]const u8 => try self.getStringyElement(element, field.name),
            []const u8 => (try self.getStringyElement(element, field.name)) orelse return Error,
            else => |field_type| switch (@typeInfo(field_type)) {
                .Struct => |s|
                    if (comptime std.mem.eql(u8, field.name, attributes_field_name))
                        try self.populateAttributes(field_type, c.ixmlNode_getAttributes(node) orelse return Error)
                    else
                        try self.populateStruct(field_type, (try self.getSingleElement(element, field.name)) orelse return Error)
                    ,
                .Pointer => |p| blk: {
                    if (@typeInfo(p.child) != .Struct) {
                        @compileError("Slices can only refer to strings or structs");
                    }
                    const elements = c.ixmlElement_getElementsByTagName(element, field.name ++ "\x00") orelse break :blk &[_]p.child {};
                    const count = c.ixmlNodeList_length(elements);
                    var resultants = try self.arena.allocator.alloc(p.child, count);
                    for (resultants) |*res, idx| {
                        const child = c.ixmlNodeList_item(elements, idx) orelse return Error;
                        res.* = try self.populateStruct(p.child, child);
                    }
                    break :blk resultants;
                },
                .Optional => |o| blk: {
                    if (@typeInfo(o.child) != .Struct) {
                        @compileError("Optional can only refer to strings or structs");
                    }
                    break :blk if (self.getSingleElement(element, field.name)) |child|
                        self.populateStruct(p.child, child)
                    else null;
                },
                else => @compileError("Invalid field '" ++ field.name ++ "' inside struct")
            }
        };
    }
    return result;
}

fn populateAttributes(self: *XMLParser, comptime T: type, attributes: *c.IXML_NamedNodeMap) !T {
    var result = T {};
    inline for (@typeInfo(T).Struct.fields) |field| {
        const value = blk: {
            const node = c.ixmlNamedNodeMap_getNamedItem(attributes, field.name ++ "\x00") orelse break :blk null;
            const raw_value = c.ixmlNode_getNodeValue(node) orelse return Error;
            break :blk try self.cloneCString(raw_value);
        };
        @field(result, field.name) = switch (field.field_type) {
            ?[]const u8 => value,
            []const u8 => value orelse return Error,
            else => @compileError("Invalid field '" ++ field.name ++ "' for attribute struct")
        };
    }
    return result;
}

fn getStringyElement(self: *XMLParser, parent: *c.IXML_Element, comptime child: []const u8) !?[]const u8 {
    const element = (try self.getSingleElement(parent, child)) orelse return null;
    const text_node = c.ixmlNode_getFirstChild(element) orelse return Error;
    if (c.ixmlNode_getNodeType(text_node) != c.eTEXT_NODE) {
        return Error;
    }
    return try self.cloneCString(c.ixmlNode_getNodeValue(text_node));
}

fn getSingleElement(self: *XMLParser, parent: *c.IXML_Element, comptime child: []const u8) !?*c.IXML_Node {
    const elements = c.ixmlElement_getElementsByTagName(parent, child ++ "\x00") orelse return null;
    const count = c.ixmlNodeList_length(elements);
    if (count > 1) {
        return Error;
    }
    return c.ixmlNodeList_item(elements, 0) orelse Error;
}

fn cloneCString(self: *XMLParser, str: [*c]const u8) ![]const u8 {
    var slice: []const u8 = undefined;
    slice.ptr = str;
    slice.len = 0;
    while (str[slice.len] != 0) : (slice.len += 1) {}
    return self.arena.allocator.dupe(u8, slice);
}
