const testing = @import("std").testing;
const xml = @import("zupnp").xml;

const TestStructure = struct {
    root: struct {
        element1: struct {
            __attributes__: struct {
                attr1: []const u8 = undefined,
                attr2: ?[]const u8 = undefined,
            } = undefined,
            child1: []const u8 = undefined,
        } = undefined,
        element2: struct {
            child2: ?[]const u8 = undefined,
            repeated: []struct {
                anotherone: []const u8 = undefined,
            } = undefined,
        } = undefined,
    } = undefined,
};

test "full structure" {
    var doc = try xml.Document.fromString(@embedFile("full.xml"));
    defer doc.deinit();
    var decode_result = try xml.decode(testing.allocator, TestStructure, doc);
    defer decode_result.deinit();
    const result = decode_result.result;

    try testing.expectEqualStrings("hello", result.root.element1.__attributes__.attr1);
    try testing.expectEqualStrings("world", result.root.element1.__attributes__.attr2.?);
    try testing.expectEqualStrings("I am required", result.root.element1.child1);
    try testing.expectEqualStrings("I am optional", result.root.element2.child2.?);
    try testing.expectEqual(@as(usize, 2), result.root.element2.repeated.len);
    try testing.expectEqualStrings("Another one", result.root.element2.repeated[0].anotherone);
    try testing.expectEqualStrings("Another two", result.root.element2.repeated[1].anotherone);
}

test "minimal structure" {
    var doc = try xml.Document.fromString(
        \\<?xml version=\"1.0\"?>
        \\<root>
        \\  <element1 attr1="hello">
        \\      <child1>I am required</child1>
        \\  </element1>
        \\  <element2>
        \\  </element2>
        \\</root>
    );
    defer doc.deinit();
    var decode_result = try xml.decode(testing.allocator, TestStructure, doc);
    defer decode_result.deinit();
    const result = decode_result.result;

    try testing.expectEqualStrings("hello", result.root.element1.__attributes__.attr1);
    try testing.expectEqual(@as(?[]const u8, null), result.root.element1.__attributes__.attr2);
    try testing.expectEqualStrings("I am required", result.root.element1.child1);
    try testing.expectEqual(@as(?[]const u8, null), result.root.element2.child2);
    try testing.expectEqual(@as(usize, 0), result.root.element2.repeated.len);
}

test "empty document" {
    var doc = try xml.Document.fromString("<?xml version=\"1.0\"?>");
    defer doc.deinit();
    try testing.expectError(xml.Error, xml.decode(testing.allocator, TestStructure, doc));
}
