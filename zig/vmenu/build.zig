const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    root_mod.addImport("zlua", zlua_dep.module("zlua"));
    root_mod.linkSystemLibrary("x11", .{});
    root_mod.linkSystemLibrary("xft", .{});
    root_mod.linkSystemLibrary("xinerama", .{});

    const exe = b.addExecutable(.{
        .name = "vmenu",
        .root_module = root_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run vmenu");
    run_step.dependOn(&run_cmd.step);
}
