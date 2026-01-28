const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimise = b.standardOptimizeOption(.{});
    const i386_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.i386 },
    });

    // ---------------------------------------------------------------
    // Build 32-bit binaries
    // ---------------------------------------------------------------

    // Define the libary module which contains all shared code
    const artlib_mod = b.addModule("artlib", .{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = i386_target,
    });

    // Define the protected mode executable elf file
    const protected_mode_mod = b.createModule(.{ .root_source_file = b.path("src/protected_mode/main.zig"), .target = i386_target, .optimize = optimise, .imports = &.{.{ .name = "artlib", .module = artlib_mod }} });
    const protected_mode = b.addExecutable(.{ .name = "ArtInium.32.elf", .root_module = protected_mode_mod });

    // use the custom linker script to load in at 64KB
    protected_mode.linker_script = b.path("linker_scripts/protected_mode.ld");

    // Extract the binary executable from the elf for use in the image
    const objcopy_32 = b.addSystemCommand(&.{
        "objcopy",
        "-O",
        "binary",
    });
    objcopy_32.addArtifactArg(protected_mode);
    const binary_32 = objcopy_32.addOutputFileArg("ArtInium.32");


    // ---------------------------------------------------------------
    // Build 16-bit binary
    // ---------------------------------------------------------------

    // Define the custom AS calls and their output object files
    const stage1a = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/stage1a.S",
        "-o",
    });
    const stage1b = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/stage1b.S",
        "-o",
    });
    const stage1a_obj = stage1a.addOutputFileArg("stage1a.o");
    const stage1b_obj = stage1b.addOutputFileArg("stage1b.o");

    // Define the executable as a linked target which zig should build - creates automatic output names etc
    const real_mode_module = b.createModule(.{ .target = i386_target, .optimize = optimise });
    const real_mode = b.addExecutable(.{ .name = "ArtInium.16", .root_module = real_mode_module });
    real_mode.setLinkerScript(b.path("linker_scripts/real_mode.ld"));
    real_mode.addObjectFile(stage1a_obj);
    real_mode.addObjectFile(stage1b_obj);

    // ---------------------------------------------------------------
    // Specify install targets so that files appear in zig-out/bin
    // ---------------------------------------------------------------
    const install_binary_16 = b.addInstallArtifact(real_mode, .{});
    const install_elf_32 = b.addInstallArtifact(protected_mode, .{});
    const install_binary_32 = b.addInstallFile(binary_32, "bin/ArtInium.32");

    // ---------------------------------------------------------------
    // Define `zig build [target]` targets
    // ---------------------------------------------------------------

    const step_16 = b.step("ArtInium.16", "Build 16-bit binary");
    step_16.dependOn(&install_binary_16.step);

    // Build the 32-bit executable as an elf file so that we can  use it for debugging purposes.
    const elf_32 = b.step("ArtInium.32.elf", "Build 32-bit binary");
    elf_32.dependOn(&install_elf_32.step);

    const step_32 = b.step("ArtInium.32", "Build 32-bit raw binary");
    step_32.dependOn(&install_binary_32.step);

    // Default to build all of them
    const build_all = b.step("build_all", "Build 16 and 32 bit binaries");
    b.default_step = build_all;

    // Create the "all" dependency tree to install all artifacts
    build_all.dependOn(step_16);
    build_all.dependOn(elf_32);
    build_all.dependOn(step_32);
    build_all.dependOn(b.getInstallStep());
}
