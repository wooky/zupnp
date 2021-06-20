const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const lib_path = b.option([]const u8, "LIB_PATH", "Path to Linux libraries") orelse "/usr/lib/x86_64-linux-gnu";

    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zupnp", "src/lib.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = addTest(b, mode, lib_path);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    var docs_tests = addTest(b, mode, lib_path);
    docs_tests.emit_docs = true;
    docs_tests.emit_bin = false;
    docs_tests.output_dir = "docs";
    const docs_step = b.step("docs", "Create documentation");
    docs_step.dependOn(&docs_tests.step);
}

fn addTest(b: *Builder, mode: std.builtin.Mode, lib_path: []const u8) *std.build.LibExeObjStep {
    var tests = b.addTest("test/tests.zig");
    tests.setBuildMode(mode);
    tests.addPackagePath("zupnp", "src/lib.zig");
    tests.linkLibC();
    tests.linkSystemLibrary("upnp");
    tests.linkSystemLibrary("ixml");
    tests.addLibPath(lib_path);
    return tests;
}
