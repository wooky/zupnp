const std = @import("std");
const Node = @import("xml.zig").Node;

const attributes_field_name = "__attributes__";
const logger = std.log.scoped(.XMLTraverser);

pub fn XMLStructTraverser(comptime Self: type, comptime Error: anyerror) type {
    return struct {
        pub fn traverseStruct(self: *Self, input: anytype, parent: Node) !void {
            inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
                try self.traverseField(&@field(input, field.name), field.name, parent);
            }
        }

        pub fn traverseField(self: *Self, input: anytype, comptime name: []const u8, parent: Node) !void {
            switch (@typeInfo(@TypeOf(input.*))) {
                .Struct => |s|
                    if (comptime std.mem.eql(u8, name, attributes_field_name)) {
                        try self.handleAttributes(name, input, parent.Element);
                    }
                    else {
                        try self.handleSubStruct(name, input, parent);
                    }
                ,
                .Pointer => |p| 
                    if (p.child == u8) {
                        try self.handleString(name, input, parent.Element);
                    }
                    else if (@typeInfo(p.child) == .Struct) {
                        try self.handlePointer(name, input, parent.Element);
                    }
                    else {
                        @compileError("Field " ++ name ++ " has invalid pointer type");
                    }
                ,
                .Optional => |o| try self.handleOptional(name, input, parent.Element),
                else => @compileError("Invalid field " ++ name ++ " inside struct")
            }
        }
    };
}
