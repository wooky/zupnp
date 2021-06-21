const std = @import("std");
const xml = @import("../lib.zig").xml;

const attributes_field_name = "__attributes__";
const item_field_name = "__item__";

pub fn StructTraverser(comptime Self: type, comptime logger: type) type {
    return struct {
        pub fn traverseStruct(self: *Self, input: anytype, parent: xml.Node) !void {
            inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
                try self.traverseField(&@field(input, field.name), field.name, parent);
            }
        }

        pub fn traverseField(self: *Self, input: anytype, comptime name: []const u8, parent: xml.Node) !void {
            switch (@typeInfo(@TypeOf(input.*))) {
                .Struct => |s|
                    if (comptime std.mem.eql(u8, name, attributes_field_name)) {
                        try self.handleAttributes(input, parent.Element);
                    }
                    else {
                        try self.handleSubStruct(name, input, parent);
                    }
                ,
                .Pointer => |p| {
                    if (@typeInfo(p.child) == .Struct) {
                        return self.handlePointer(name, input, parent.Element);
                    }
                    if (comptime !std.mem.eql(u8, name, item_field_name)) {
                        return self.handleSingleItem(name, input, parent.Element);
                    }
                    if (p.child == u8) {
                        return self.handleString(name, input, parent.Element);
                    }
                    @compileError("Field " ++ name ++ " has unsupported pointer type " ++ @typeName(p.child));
                },
                .Optional => |o| try self.handleOptional(name, input, parent.Element),
                else => @compileError("Unsupported field " ++ name ++ " inside struct")
            }
        }
    };
}
