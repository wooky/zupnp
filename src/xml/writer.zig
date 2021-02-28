const c = @import("../c.zig");
const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const Error = error.XMLWriteError;

const XMLWriter = @This();
const logger = std.log.scoped(.XMLWriter);
const attributes_field_name = "__attributes__";

arena: ArenaAllocator,
doc_handle: [*c]c.IXML_Document = undefined,

pub fn init(allocator: *std.mem.Allocator) XMLWriter {
    return .{ .arena = ArenaAllocator.init(allocator) };
}

pub fn deinit(self: *XMLWriter) void {
    self.arena.deinit();
}

pub fn writeStructToDocumentString(self: *XMLWriter, input: anytype) ![:0]const u8 {
    const handle = try self.writeStructToDocumentHandle(input);
    defer c.ixmlDocument_free(handle);
    const doc = c.ixmlPrintDocument(handle) orelse {
        logger.err("Failed to convert document handle to string", .{});
        return Error;
    };
    defer c.ixmlFreeDOMString(doc);
    var doc_slice: []const u8 = undefined;
    doc_slice.ptr = doc;
    doc_slice.len = 0;
    while (doc[doc_slice.len] != 0) : (doc_slice.len += 1) {}
    return self.arena.allocator.dupeZ(u8, doc_slice);
}

pub fn writeStructToDocumentHandle(self: *XMLWriter, input: anytype) !*c.IXML_Document {
    const err = c.ixmlDocument_createDocumentEx(&self.doc_handle);
    if (err != c.IXML_SUCCESS) {
        logger.err("Failed to create document: {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
        return Error;
    }

    try self.readFromStruct(input, @ptrCast(*c.IXML_Node, self.doc_handle));
    return self.doc_handle;
}

fn readFromStruct(self: *XMLWriter, input: anytype, parent: *c.IXML_Node) !void {
    inline for (@typeInfo(@TypeOf(input)).Struct.fields) |field| {
        try self.readField(@field(input, field.name), field.name, parent);
    }
}

fn readField(self: *XMLWriter, input: anytype, comptime name: []const u8, parent: *c.IXML_Node) !void {
    switch (@typeInfo(@TypeOf(input))) {
        .Struct => |s| {
            if (comptime std.mem.eql(u8, name, attributes_field_name)) {
                try self.writeAttributes(input, @ptrCast(*c.IXML_Element, parent));
            }
            else {
                var sub_parent = try self.createNode(name);
                try self.readFromStruct(input, sub_parent);
                try append(parent, sub_parent);
            }
        },
        .Pointer => |p| {
            if (p.child == u8) {
                try self.writeString(name, input, parent);
            }
            else {
                for (input) |subinput| {
                    try self.readField(subinput, name, parent);
                }
            }
        },
        .Optional => if (input) |i| try self.readField(i, name, parent),
        else => @compileError("Invalid field '" ++ input_info.name ++ "' inside struct")
    }
}

fn createNode(self: *XMLWriter, comptime name: []const u8) !*c.IXML_Node {
    var node: [*c]c.IXML_Element = undefined;
    const err = c.ixmlDocument_createElementEx(self.doc_handle, name ++ "\x00", &node);
    if (err != c.IXML_SUCCESS) {
        logger.err("Failed to create element: {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
        return Error;
    }
    return @ptrCast([*c]c.IXML_Node, node);
}

fn append(parent: *c.IXML_Node, child: *c.IXML_Node) !void {
    const err = c.ixmlNode_appendChild(parent, child);
    if (err != c.IXML_SUCCESS) {
        logger.err("Failed to append node: {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
        return Error;
    }
}

fn writeString(self: *XMLWriter, comptime name: []const u8, value: []const u8, parent: *c.IXML_Node) !void {
    var node = try self.createNode(name);
    var text: [*c]c.IXML_Node = undefined;

    {
        const err = c.ixmlDocument_createTextNodeEx(self.doc_handle, name ++ "\x00", &text);
        if (err != c.IXML_SUCCESS) {
            logger.err("Failed to create text node: {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
            return Error;
        }
    }

    {
        const err = c.ixmlNode_setNodeValue(text, try self.arena.allocator.dupeZ(u8, value));
        if (err != c.IXML_SUCCESS) {
            logger.err("Failed to set text node value: {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
            return Error;
        }
    }

    try append(node, text);
    try append(parent, node);
}

fn writeAttributes(self: *XMLWriter, input: anytype, element: *c.IXML_Element) !void {
    inline for (@typeInfo(@TypeOf(input)).Struct.fields) |field| {
        const field_value_opt: ?[]const u8 = @field(input, field.name);
        if (field_value_opt) |field_value| {
            const err = c.ixmlElement_setAttribute(element, field.name ++ "\x00", try self.arena.allocator.dupeZ(u8, field_value));
            if (err != c.IXML_SUCCESS) {
                logger.err("Failed to set attribute: {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
                return Error;
            }
        }
    }
}
