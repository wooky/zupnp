const std = @import("std");
const testing = std.testing;
const xml = @import("zupnp").xml;

const Repeated = struct {
    anotherone: struct {
        __attributes__: struct {
            optionalattr: ?[]const u8 = null,
        } = .{},
        __item__: []const u8
    }
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
                        .anotherone = .{
                            .__item__ = "Another one"
                        },
                    },
                    .{
                        .anotherone = .{
                            .__attributes__ = .{
                                .optionalattr = "yes",
                            },
                            .__item__ = "Another two",
                        },
                    },
                },
            },
        },
    };
    var doc = try xml.encode(testing.allocator, input);
    defer doc.deinit();
    var result = try doc.toString();
    defer result.deinit();

    var buf: [512]u8 = undefined;
    const expected_xml = @embedFile("full.xml");
    try testing.expectEqualStrings(expected_xml, result.string);
}
