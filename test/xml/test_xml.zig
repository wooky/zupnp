const std = @import("std");
const testing = std.testing;
const Document = @import("zupnp").xml.Document;

test "writing XML" {
    var doc = try Document.new();
    defer doc.deinit();

    var root = try doc.createElement("root");
    try doc.appendChild(root);

    {
        var element1 = try doc.createElement("element1");
        try root.appendChild(element1);
        try element1.setAttribute("attr1", "hello");
        try element1.setAttribute("attr2", "world");

        {
            var child1 = try doc.createElement("child1");
            try element1.appendChild(child1);

            var child1_text = try doc.createTextNode("I am required");
            try child1.appendChild(child1_text);
        }
    }

    {
        var element2 = try doc.createElement("element2");
        try root.appendChild(element2);

        {
            var child2 = try doc.createElement("child2");
            try element2.appendChild(child2);

            var child2_text = try doc.createTextNode("I am optional");
            try child2.appendChild(child2_text);
        }

        {
            var repeated = try doc.createElement("repeated");
            try element2.appendChild(repeated);

            var anotherone = try doc.createElement("anotherone");
            try repeated.appendChild(anotherone);

            var anotherone_text = try doc.createTextNode("Another one");
            try anotherone.appendChild(anotherone_text);
        }

        {
            var repeated = try doc.createElement("repeated");
            try element2.appendChild(repeated);

            var anotherone = try doc.createElement("anotherone");
            try repeated.appendChild(anotherone);

            var anotherone_text = try doc.createTextNode("Another two");
            try anotherone.appendChild(anotherone_text);
        }
    }

    var string = try doc.toString();
    defer string.deinit();
    testing.expectEqualSlices(u8, @embedFile("full.xml"), string.string);
}

test "parsing XML" {
    var doc = try Document.fromString(@embedFile("full.xml"));
    defer doc.deinit();

    const root = (try doc.getElementsByTagName("root").getSingleItem()).Element;

    const element1 = (try root.getElementsByTagName("element1").getSingleItem()).Element;
    testing.expectEqualSlices(u8, "hello", element1.getAttribute("attr1").?);
    testing.expectEqualSlices(u8, "world", element1.getAttribute("attr2").?);
    testing.expect(element1.getAttribute("bogus") == null);

    const child1 = (try element1.getElementsByTagName("child1").getSingleItem()).Element;
    const child1_text = (try child1.getFirstChild()).?.TextNode;
    testing.expectEqualSlices(u8, "I am required", child1_text.getValue());

    const bogus_children = element1.getElementsByTagName("bogus");
    testing.expectEqual(@as(usize, 0), bogus_children.getLength());

    const element2 = (try root.getElementsByTagName("element2").getSingleItem()).Element;

    const child2 = (try element2.getElementsByTagName("child2").getSingleItem()).Element;
    const child2_text = (try child2.getFirstChild()).?.TextNode;
    testing.expectEqualSlices(u8, "I am optional", child2_text.getValue());

    var repeated_iter = element2.getElementsByTagName("repeated").iterator();

    const repeated1 = (try repeated_iter.next()).?.Element;
    const anotherone1 = (try repeated1.getElementsByTagName("anotherone").getSingleItem()).Element;
    const anotherone1_text = (try anotherone1.getFirstChild()).?.TextNode;
    testing.expectEqualSlices(u8, "Another one", anotherone1_text.getValue());

    const repeated2 = (try repeated_iter.next()).?.Element;
    const anotherone2 = (try repeated2.getElementsByTagName("anotherone").getSingleItem()).Element;
    const anotherone2_text = (try anotherone2.getFirstChild()).?.TextNode;
    testing.expectEqualSlices(u8, "Another two", anotherone2_text.getValue());

    testing.expect((try repeated_iter.next()) == null);
}
