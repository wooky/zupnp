test "web client" {
    _ = @import("web/test_client.zig");
}

test "web server" {
    _ = @import("web/test_server.zig");
}

test "XML library" {
    _ = @import("xml/test_xml.zig");
}

test "XML decode" {
    _ = @import("xml/test_decode.zig");
}

test "XML encode" {
    _ = @import("xml/test_encode.zig");
}
