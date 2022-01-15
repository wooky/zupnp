const std = @import("std");
const Builder = std.build.Builder;

const Paths = struct {
    upnp_header_path: []const u8,
    ixml_header_superpath: []const u8,
    upnp_lib_path: []const u8,
    ixml_lib_path: []const u8,
};

pub fn queryPaths(b: *Builder) Paths {
    return Paths {
        .upnp_header_path = b.option([]const u8, "UPNP_HEADER_PATH", "Path to libupnp headers") orelse "/usr/include/upnp",
        .ixml_header_superpath = b.option([]const u8, "IXML_HEADER_SUPERPATH", "Path to parent directory of libixml headers") orelse "/usr/include",
        .upnp_lib_path = b.option([]const u8, "UPNP_LIB_PATH", "Path to libupnp library") orelse "/usr/lib/x86_64-linux-gnu",
        .ixml_lib_path = b.option([]const u8, "IXML_LIB_PATH", "Path to libixml library") orelse "/usr/lib/x86_64-linux-gnu",
    };
}

pub fn populateStep(step: *std.build.LibExeObjStep, paths: Paths) void {
    step.linkLibC();
    step.linkSystemLibrary("upnp");
    step.linkSystemLibrary("ixml");
    step.addIncludeDir(paths.upnp_header_path);
    step.addIncludeDir(paths.ixml_header_superpath);
    step.addLibPath(paths.upnp_lib_path);
    step.addLibPath(paths.ixml_lib_path);
}

pub fn build(b: *Builder) void {
    const paths = queryPaths(b);
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zupnp", "src/lib.zig");
    lib.setBuildMode(mode);
    lib.addPackagePath("xml", "vendor/xml/src/lib.zig");
    lib.install();

    var main_tests = addTest(b, mode, paths);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    var docs_tests = addTest(b, mode, paths);
    docs_tests.emit_docs = .emit;
    docs_tests.emit_bin = .no_emit;
    docs_tests.output_dir = "docs";
    const docs_step = b.step("docs", "Create documentation");
    docs_step.dependOn(&docs_tests.step);
}

fn addTest(b: *Builder, mode: std.builtin.Mode, paths: Paths) *std.build.LibExeObjStep {
    var tests = b.addTest("test/tests.zig");
    tests.setBuildMode(mode);
    // TODO https://github.com/ziglang/zig/issues/855
    const xml_package = std.build.Pkg{ .name = "xml", .path = .{ .path = "vendor/xml/src/lib.zig" } };
    const zupnp_package = std.build.Pkg{ .name = "zupnp", .path = .{ .path = "src/lib.zig" }, .dependencies = &[_]std.build.Pkg{ xml_package } };
    tests.addPackage(zupnp_package);
    populateStep(tests, paths);
    return tests;
}
