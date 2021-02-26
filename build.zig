const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const lib_path = b.option([]const u8, "LIB_PATH", "Path to Linux libraries") orelse "/usr/lib/x86_64-linux-gnu";

    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zupnp", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("test/tests.zig");
    main_tests.setBuildMode(mode);
    main_tests.addPackagePath("zupnp", "src/main.zig");
    main_tests.linkLibC();
    main_tests.linkSystemLibrary("upnp");
    main_tests.linkSystemLibrary("ixml");
    main_tests.addLibPath(lib_path);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
