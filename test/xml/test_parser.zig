const testing = @import("std").testing;
const Parser = @import("zupnp").xml.Parser;

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
    const xml = @embedFile("full.xml");
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();
    const result = try parser.parseDocumentFromString(TestStructure, xml);

    testing.expectEqualStrings("hello", result.root.element1.__attributes__.attr1);
    testing.expectEqualStrings("world", result.root.element1.__attributes__.attr2.?);
    testing.expectEqualStrings("I am required", result.root.element1.child1);
    testing.expectEqualStrings("I am optional", result.root.element2.child2.?);
    testing.expectEqual(@as(usize, 2), result.root.element2.repeated.len);
    testing.expectEqualStrings("Another one", result.root.element2.repeated[0].anotherone);
    testing.expectEqualStrings("Another two", result.root.element2.repeated[1].anotherone);
}

test "minimal structure" {
    const xml =
        \\<?xml version=\"1.0\"?>
        \\<root>
        \\  <element1 attr1="hello">
        \\      <child1>I am required</child1>
        \\  </element1>
        \\  <element2>
        \\  </element2>
        \\</root>
        ;
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();
    const result = try parser.parseDocumentFromString(TestStructure, xml);

    testing.expectEqualStrings("hello", result.root.element1.__attributes__.attr1);
    testing.expectEqual(@as(?[]const u8, null), result.root.element1.__attributes__.attr2);
    testing.expectEqualStrings("I am required", result.root.element1.child1);
    testing.expectEqual(@as(?[]const u8, null), result.root.element2.child2);
    testing.expectEqual(@as(usize, 0), result.root.element2.repeated.len);
}

test "empty string" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();
    testing.expectError(error.XMLParseError, parser.parseDocumentFromString(TestStructure, ""));
}

test "empty document" {
    const xml = "<?xml version=\"1.0\"?>";
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();
    testing.expectError(error.XMLParseError, parser.parseDocumentFromString(TestStructure, xml));
}
