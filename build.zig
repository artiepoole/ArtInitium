const std = @import("std");

pub fn build(b: *std.Build) void {

    // ---------------------------------------------------------------
    // Build 32-bit binary
    // ---------------------------------------------------------------

    const optimise = b.standardOptimizeOption(.{});
    const i386_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.i386 },
    });

    const artlib_mod = b.addModule("artlib", .{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = i386_target,
    });

    const protected_mode_mod = b.createModule(.{
        .root_source_file = b.path("src/protected_mode/main.zig"),
        .target = i386_target,
        .optimize = optimise,
        .imports = &.{
            .{ .name = "artlib", .module = artlib_mod }
        }
    });

    const protected_mode = b.addExecutable(.{ .name = "ArtInium.32", .root_module = protected_mode_mod });

    //custom linker script to load in at 64KB
    protected_mode.linker_script = b.path("linker_scripts/protected_mode.ld");

    b.installArtifact(protected_mode);

    // Make this the default build step
    const step_32 = b.step("ArtInium.32", "Build 32-bit binary");
    step_32.dependOn(&protected_mode.step);

    // ---------------------------------------------------------------
    // Build 16-bit binary
    // ---------------------------------------------------------------

    const stage1a = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/stage1a.S",
        "-o",
        "zig-out/stage1a.o",
    });
    const stage1b = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/stage1b.S",
        "-o",
        "zig-out/stage1b.o",
    });
    const link = b.addSystemCommand(&.{
        "ld",
        "-T",
        "linker_scripts/real_mode.ld",
        "zig-out/stage1a.o",
        "zig-out/stage1b.o",
        "-o",
        "zig-out/bin/ArtInium.16",
    });
    const step_16 = b.step("ArtInium.16", "Build 16-bit binary");
    step_16.dependOn(&stage1a.step);
    step_16.dependOn(&stage1b.step);
    step_16.dependOn(&link.step);

    const build_all = b.step("build_all", "Build 16 and 32 bit binaries");
    b.default_step = build_all;
    build_all.dependOn(step_16);
    build_all.dependOn(step_32);
    build_all.dependOn(b.getInstallStep());
}
