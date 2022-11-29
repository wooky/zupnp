const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("mediaserver", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.addIncludePath("/usr/include/upnp");
    exe.linkLibC();
    exe.linkSystemLibrary("upnp");
    exe.linkSystemLibrary("ixml");
    // TODO https://github.com/ziglang/zig/issues/855
    const xml_package = std.build.Pkg{ .name = "xml", .source = .{ .path = "../../vendor/xml/src/lib.zig" } };
    const zupnp_package = std.build.Pkg{ .name = "zupnp", .source = .{ .path = "../../src/lib.zig" }, .dependencies = &[_]std.build.Pkg{ xml_package } };
    exe.addPackage(zupnp_package);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
