const c = @import("../c.zig");
const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const Error = error.XMLError;

const logger = std.log.scoped(.XML);

pub fn AbstractNode(comptime NodeType: type) type {
    return struct {
        pub fn getChildNodes(self: *const NodeType) NodeList {
            return NodeList.init(c.ixmlNode_getChildNodes(@ptrCast(*c.IXML_Node, self.handle)));
        }

        pub fn getFirstChild(self: *const NodeType) !?Node {
            if (c.ixmlNode_getFirstChild(@ptrCast(*c.IXML_Node, self.handle))) |child_handle| {
                return try Node.fromHandle(child_handle);
            }
            return null;
        }

        pub fn appendChild(self: *const NodeType, child: anytype) !void {
            try check(c.ixmlNode_appendChild(@ptrCast(*c.IXML_Node, self.handle), @ptrCast(*c.IXML_Node, child.handle)), "Failed to append child", "err");
        }

        pub fn toNode(self: *const NodeType) !Node {
            return try Node.fromHandle(@ptrCast(*c.IXML_Node, self.handle));
        }
    };
}

pub const Node = union(enum) {
    Document: Document,
    Element: Element,
    TextNode: TextNode,

    fn fromHandle(handle: *c.IXML_Node) !Node {
        return switch (c.ixmlNode_getNodeType(handle)) {
            c.eDOCUMENT_NODE => Node { .Document = Document.init(@ptrCast(*c.IXML_Document, handle)) },
            c.eELEMENT_NODE => Node { .Element = Element.init(@ptrCast(*c.IXML_Element, handle)) },
            c.eTEXT_NODE => Node { .TextNode = TextNode.init(handle) },
            else => |node_type| {
                logger.err("Unhandle XML node type {}", .{@intToEnum(c.IXML_NODE_TYPE, node_type)});
                return Error;
            }
        };
    }
};

pub const Document = struct {
    usingnamespace AbstractNode(Document);

    handle: *c.IXML_Document,

    pub fn new() !Document {
        var handle: [*c]c.IXML_Document = undefined;
        try check(c.ixmlDocument_createDocumentEx(&handle), "Failed to create document", "err");
        return Document.init(handle);
    }

    pub fn fromString(doc: [:0]const u8) !Document {
        var handle: [*c]c.IXML_Document = undefined;
        try check(c.ixmlParseBufferEx(doc, &handle), "Cannot parse document from string", "warn");
        return Document.init(handle);
    }

    pub fn init(handle: *c.IXML_Document) Document {
        return Document { .handle = handle };
    }

    pub fn deinit(self: *const Document) void {
        c.ixmlDocument_free(self.handle);
    }

    pub fn createElement(self: *const Document, tag_name: [:0]const u8) !Element {
        var element_handle: [*c]c.IXML_Element = undefined;
        try check(c.ixmlDocument_createElementEx(self.handle, tag_name, &element_handle), "Failed to create element", "err");
        return Element.init(element_handle);
    }

    pub fn createTextNode(self: *const Document, data: [:0]const u8) !TextNode {
        var node_handle: [*c]c.IXML_Node = undefined;
        try check(c.ixmlDocument_createTextNodeEx(self.handle, data, &node_handle), "Failed to create text node", "err");
        return TextNode.init(node_handle);
    }

    pub fn getElementsByTagName(self: *const Document, tag_name: [:0]const u8) NodeList {
        return NodeList.init(c.ixmlDocument_getElementsByTagName(self.handle, tag_name));
    }

    pub fn toString(self: *const Document) !DOMString {
        if (c.ixmlDocumenttoString(self.handle)) |string| {
            return DOMString.init(cStringToSlice(string));
        }
        logger.err("Failed to render document to string", .{});
        return Error;
    }
};

pub const Element = struct {
    usingnamespace AbstractNode(Element);

    handle: *c.IXML_Element,

    pub fn init(handle: *c.IXML_Element) Element {
        return Element { .handle = handle };
    }

    pub fn getAttribute(self: *const Element, name: [:0]const u8) ?[]const u8 {
        if (c.ixmlElement_getAttribute(self.handle, name)) |attr| {
            return cStringToSlice(attr);
        }
        return null;
    }

    pub fn setAttribute(self: *const Element, name: [:0]const u8, value: [:0]const u8) !void {
        try check(c.ixmlElement_setAttribute(self.handle, name, value), "Failed to set attribute", "err");
    }

    pub fn removeAttribute(self: *const Element, name: [:0]const u8) !void {
        try check(c.ixmlElement_removeAttribute(self.handle, name), "Failed to remove attriute", "err");
    }

    pub fn getAttributes(self: *const Element) AttributeMap {
        return AttributeMap.init(c.ixmlNode_getAttributes(@ptrCast(*c.IXML_Node, self.handle)));
    }

    pub fn getElementsByTagName(self: *const Element, tag_name: [:0]const u8) NodeList {
        return NodeList.init(c.ixmlElement_getElementsByTagName(self.handle, tag_name));
    }
};

pub const TextNode = struct {
    usingnamespace AbstractNode(TextNode);

    handle: *c.IXML_Node,

    pub fn init(handle: *c.IXML_Node) TextNode {
        return TextNode { .handle = handle };
    }

    pub fn getValue(self: *const TextNode) [:0]const u8 {
        return cStringToSlice(c.ixmlNode_getNodeValue(self.handle));
    }

    pub fn setValue(self: *const TextNode, value: [:0]const u8) !void {
        try check(c.ixmlNode_setNodeValue(self.handle, value), "Failed to set text node value", "err");
    }
};

pub const NodeList = struct {
    handle: ?*c.IXML_NodeList,

    pub fn init(handle: ?*c.IXML_NodeList) NodeList {
        return NodeList { .handle = handle };
    }

    pub fn getLength(self: *const NodeList) usize {
        return if (self.handle) |h|
            c.ixmlNodeList_length(h)
        else
            0;
    }

    pub fn getItem(self: *const NodeList, index: usize) !Node {
        if (self.handle) |h| {
            if (c.ixmlNodeList_item(self.handle, index)) |item_handle| {
                return try Node.fromHandle(item_handle);
            }
            logger.err("Cannot query node list item", .{});
            return Error;
        }
        logger.err("Cannot query empty node list", .{});
        return Error;
    }

    pub fn getSingleItem(self: *const NodeList) !Node {
        const length = self.getLength();
        if (length != 1) {
            logger.warn("Node list expected to have 1 item, actual {}", .{length});
            return Error;
        }
        return self.getItem(0);
    }

    pub fn iterator(self: *const NodeList) Iterator {
        return Iterator.init(self);
    }

    pub const Iterator = struct {
        node_list: *const NodeList,
        length: usize,
        idx: usize = 0,

        fn init(node_list: *const NodeList) Iterator {
            return Iterator {
                .node_list = node_list,
                .length = node_list.getLength(),
            };
        }

        pub fn next(self: *Iterator) !?Node {
            if (self.idx < self.length) {
                var node = try self.node_list.getItem(self.idx);
                self.idx += 1;
                return node;
            }
            return null;
        }
    };
};

pub const AttributeMap = struct {
    handle: *c.IXML_NamedNodeMap,

    pub fn init(handle: *c.IXML_NamedNodeMap) AttributeMap {
        return AttributeMap { .handle = handle };
    }

    pub fn getNamedItem(self: *const AttributeMap, name: [:0]const u8) ?TextNode {
        if (c.ixmlNamedNodeMap_getNamedItem(self.handle, name)) |child_handle| {
            return TextNode.init(child_handle);
        }
        return null;
    }
};

pub const DOMString = struct {
    string: [:0]const u8,

    pub fn init(string: [:0]const u8) DOMString {
        return DOMString { .string = string };
    }

    pub fn deinit(self: *DOMString) void {
        c.ixmlFreeDOMString(@intToPtr([*c]u8, @ptrToInt(self.string.ptr)));
    }
};

fn check(err: c_int, comptime message: []const u8, comptime severity: []const u8) !void {
    if (err != c.IXML_SUCCESS) {
        @field(logger, severity)(message ++ ": {}", .{@intToEnum(c.IXML_ERRORCODE, err)});
        return Error;
    }
}

fn cStringToSlice(str: [*:0]const u8) [:0]const u8 {
    var slice: [:0]const u8 = undefined;
    slice.ptr = str;
    slice.len = 0;
    while (str[slice.len] != 0) : (slice.len += 1) {}
    return slice;
}
