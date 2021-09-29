const std = @import("std");

pub fn concatStructDeclarations(comptime structs: anytype) type {
    const fields = comptime blk: {
        var fields: []const std.builtin.TypeInfo.StructField = &.{};
        inline for (structs) |s| {
            fields = fields ++ @typeInfo(s).Struct.fields;
        }
        break :blk fields;
    };
    const generated_struct = std.builtin.TypeInfo.Struct {
        .layout = .Auto,
        .fields = fields,
        .decls = &.{},
        .is_tuple = false,
    };
    return @Type(.{ .Struct = generated_struct });
}
