const std = @import("std");
const testing = std.testing;
const Writer = @import("zupnp").xml.Writer;

const Repeated = struct {
    anotherone: []const u8,
};
const TestStructure = struct {
    root: struct {
        element1: struct {
            __attributes__: struct {
                attr1: []const u8,
                attr2: ?[]const u8,
            },
            child1: []const u8,
        },
        element2: struct {
            child2: ?[]const u8,
            repeated: []const Repeated,
        },
    },
};

test "full structure" {
    const input = TestStructure {
        .root = .{
            .element1 = .{
                .__attributes__ = .{
                    .attr1 = "hello",
                    .attr2 = "world",
                },
                .child1 = "I am required",
            },
            .element2 = .{
                .child2 = "I am optional",
                .repeated = &[_] Repeated {
                    .{
                        .anotherone = "Another one",
                    },
                    .{
                        .anotherone = "Another two",
                    },
                },
            },
        },
    };
    var writer = Writer.init(testing.allocator);
    defer writer.deinit();
    var doc = try writer.writeStructToDocument(input);
    defer doc.deinit();
    var result = try doc.toString();
    defer result.deinit();

    var buf: [512]u8 = undefined;
    const expected_xml = @embedFile("full.xml");
    testing.expectEqualSlices(u8, expected_xml, result.string);
}
