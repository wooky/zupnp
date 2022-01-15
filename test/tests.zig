test "load tests" {
    _ = @import("web/test_chunked_get_requests.zig");
    _ = @import("web/test_get_requests.zig");
    _ = @import("web/test_misc_responses.zig");
    _ = @import("web/test_post_requests.zig");
    _ = @import("web/test_server_internals.zig");
}
