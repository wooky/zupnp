const c = @import("../c.zig");
const std = @import("std");

const attributes_field_name = "__attributes__";

pub fn XMLStructTraverser(comptime Self: type) type {
    return struct {
        pub fn traverseStruct(self: *Self, input: anytype, parent: *c.IXML_Node) !void {
            try self.precheckNode(parent);
            inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
                try self.traverseField(&@field(input, field.name), field.name, parent);
            }
        }

        pub fn traverseField(self: *Self, input: anytype, comptime name: []const u8, parent: *c.IXML_Node) !void {
            switch (@typeInfo(@TypeOf(input.*))) {
                .Struct => |s|
                    if (comptime std.mem.eql(u8, name, attributes_field_name)) {
                        try self.handleAttributes(name, input, parent);
                    }
                    else {
                        try self.handleSubStruct(name, input, parent);
                    }
                ,
                .Pointer => |p| 
                    if (p.child == u8) {
                        try self.handleString(name, input, parent);
                    }
                    else if (@typeInfo(p.child) == .Struct) {
                        try self.handlePointer(name, input, parent);
                    }
                    else {
                        @compileError("Field " ++ name ++ " has invalid pointer type");
                    }
                ,
                .Optional => |o| try self.handleOptional(name, input, parent),
                else => @compileError("Invalid field " ++ name ++ " inside struct")
            }
        }
    };
}
