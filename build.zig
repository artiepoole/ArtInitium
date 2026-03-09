const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const optimise = b.standardOptimizeOption(.{});

    const arch_option = b.option(
        []const u8,
        "arch",
        "Target architecture: x86_32, arm64, or 'all' (default: x86_32)",
    ) orelse "x86_32";

    const arm64_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .freestanding,
    });

    // just use it to avoid "unused variable" compile error for now, since we can't build arm64 yet
    _ = arm64_target;

    const build_x86 =
        std.mem.eql(u8, arch_option, "x86_32") or
        std.mem.eql(u8, arch_option, "all");
    const build_arm64 =
        std.mem.eql(u8, arch_option, "arm64") or
        std.mem.eql(u8, arch_option, "all");

    // Build x86_32 if requested
    if (build_x86) {
        buildX86(b, optimise);
    }

    // Build ARM64 if requested
    if (build_arm64) {
        buildArm64(b, optimise);
    }
}

fn buildX86(b: *std.Build, optimise: std.builtin.OptimizeMode) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.i386 },
    });

    // ---------------------------------------------------------------
    // Build 16-bit binary
    // ---------------------------------------------------------------

    // Define the custom AS calls and their output object files
    const assemble_stage1a = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/x86_32/stage1a.S",
        "-o",
    });
    const assemble_stage1b = b.addSystemCommand(&.{
        "as",
        "--32",
        "src/real_mode/x86_32/stage1b.S",
        "-o",
    });
    const stage1a_obj = assemble_stage1a.addOutputFileArg("stage1a.o");
    const stage1b_obj = assemble_stage1b.addOutputFileArg("stage1b.o");

    // Define the executable as a linked target which zig should build - creates automatic output names etc
    const real_mode_module = b.createModule(.{ .target = target, .optimize = optimise });
    const real_mode_exe = b.addExecutable(.{ .name = "ArtInitium.16.x86_32.elf", .root_module = real_mode_module });
    real_mode_exe.setLinkerScript(b.path("linker_scripts/x86_32/real_mode.ld"));
    real_mode_exe.addObjectFile(stage1a_obj);
    real_mode_exe.addObjectFile(stage1b_obj);

    // Extract stage1a (MBR, first 512 bytes) from the linked ELF by section
    const objcopy_stage1a = b.addSystemCommand(&.{
        "objcopy", "--only-section=.stage1a", "-O", "binary",
    });
    objcopy_stage1a.addArtifactArg(real_mode_exe);
    const stage1a_bin = objcopy_stage1a.addOutputFileArg("ArtInitium.16.x86_32.a");

    // Extract stage1b (real-mode loader) from the linked ELF by section
    const objcopy_stage1b = b.addSystemCommand(&.{
        "objcopy", "--only-section=.stage1b", "-O", "binary",
    });
    objcopy_stage1b.addArtifactArg(real_mode_exe);
    const stage1b_bin = objcopy_stage1b.addOutputFileArg("ArtInitium.16.x86_32.b");

    // Also produce the combined flat binary (stage1a + stage1b) for reference
    const objcopy_16 = b.addSystemCommand(&.{
        "objcopy", "-O", "binary",
    });
    objcopy_16.addArtifactArg(real_mode_exe);
    const binary_16_output = objcopy_16.addOutputFileArg("ArtInitium.16.x86_32");

    const install_stage1a = b.addInstallFile(stage1a_bin, "bin/ArtInitium.16.x86_32.a");
    const install_stage1b = b.addInstallFile(stage1b_bin, "bin/ArtInitium.16.x86_32.b");
    const install_binary_16 = b.addInstallFile(binary_16_output, "bin/ArtInitium.16.x86_32");
    const install_elf_16 = b.addInstallArtifact(real_mode_exe, .{});

    // ---------------------------------------------------------------
    // Build 32-bit binaries
    // ---------------------------------------------------------------

    // Define the libary module which contains all shared code
    const artlib_mod = b.addModule("artlib", .{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
    });

    // Define the protected mode executable elf file
    const elf_32_mod = b.createModule(
        .{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimise,
            .imports = &.{
                .{
                    .name = "artlib",
                    .module = artlib_mod,
                },
            },
        },
    );
    const elf_32_exe = b.addExecutable(
        .{
            .name = "ArtInitium.32.x86_32.elf",
            .root_module = elf_32_mod,
        },
    );

    // use the custom linker script to load in at 64KB
    elf_32_exe.linker_script = b.path("linker_scripts/x86_32/protected_mode.ld");

    // Extract the binary executable from the elf for use in the image
    const objcopy_32 = b.addSystemCommand(&.{
        "objcopy",
        "-O",
        "binary",
    });
    objcopy_32.addArtifactArg(elf_32_exe);
    const binary_32_output = objcopy_32.addOutputFileArg("ArtInitium.32.x86_32");

    // ---------------------------------------------------------------
    // Specify install targets so that files appear in zig-out/bin
    // ---------------------------------------------------------------
    const install_elf_32 = b.addInstallArtifact(elf_32_exe, .{});
    const install_binary_32 = b.addInstallFile(binary_32_output, "bin/ArtInitium.32.x86_32");

    // ---------------------------------------------------------------
    // Assemble disk image using dtc + binman
    // ---------------------------------------------------------------

    // Compile the .its to a .dtb
    const dtc = b.addSystemCommand(&.{
        "dtc",
        "-I", "dts",
        "-O", "dtb",
        "-o",
    });
    const dtb_output = dtc.addOutputFileArg("artinium_x86_32.dtb");
    dtc.addArg("image_layouts/artinium_x86_32.its");

    // Run binman with the compiled .dtb, passing zig-tracked artifact dirs as inputs
    const binman = b.addSystemCommand(&.{ "binman", "build", "-d" });
    binman.addFileArg(dtb_output);
    // Pass the directories containing each artifact as -I so binman can find them by filename
    binman.addArg("-I");
    binman.addDirectoryArg(stage1a_bin.dirname());
    binman.addArg("-I");
    binman.addDirectoryArg(stage1b_bin.dirname());
    binman.addArg("-I");
    binman.addDirectoryArg(binary_32_output.dirname());
    // Capture output directory as a zig-tracked path
    binman.addArg("-O");
    const image_out_dir = binman.addOutputDirectoryArg("binman_out");

    // Reference the image file within the tracked output directory
    const image_file = image_out_dir.path(b, "artinitium.x86_32.img");
    const install_image = b.addInstallFile(image_file, "bin/artinitium.x86_32.img");

    // ---------------------------------------------------------------
    // Define `zig build [target]` targets
    // ---------------------------------------------------------------

    const step_16 = b.step("ArtInitium.16", "Build 16-bit binary");
    step_16.dependOn(&install_binary_16.step);
    step_16.dependOn(&install_elf_16.step);
    step_16.dependOn(&install_stage1a.step);
    step_16.dependOn(&install_stage1b.step);

    // Build the 32-bit executable as an elf file so that we can use it for debugging purposes.
    const elf_32 = b.step("ArtInitium.32.elf", "Build 32-bit binary");
    elf_32.dependOn(&install_elf_32.step);

    const step_32 = b.step("ArtInitium.32", "Build 32-bit raw binary");
    step_32.dependOn(&install_binary_32.step);

    // Default to build all of them
    const build_all = b.step("build_all", "Build 16 and 32 bit binaries");
    b.default_step = build_all;

    // Create the "all" dependency tree to install all artifacts
    build_all.dependOn(step_16);
    build_all.dependOn(elf_32);
    build_all.dependOn(step_32);
    build_all.dependOn(&install_image.step);

    const make_image = b.step("make_image", "Assemble disk image using binman");
    make_image.dependOn(build_all);

    const clean_step = b.addRemoveDirTree(b.path("zig-out"));
    const clean_cache = b.addRemoveDirTree(b.path(".zig-cache"));
    const clean = b.step("clean", "Remove build outputs");
    clean.dependOn(&clean_step.step);
    clean.dependOn(&clean_cache.step);

    // ---------------------------------------------------------------
    // Create test target to run library Unit tests on host
    // ---------------------------------------------------------------
    const host_target = b.standardTargetOptions(.{});
    const artlib_test_mod = b.createModule(.{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = host_target,
    });

    const mod_tests = b.addTest(.{
        .root_module = artlib_test_mod,
        .use_llvm = true,
        .use_lld = true,
    });

    const install_mod_tests = b.addInstallArtifact(
        mod_tests,
        .{
            .dest_dir = .{
                .override = .{
                    .custom = "test_artlib",
                },
            },
        },
    );

    const mod_tests_step = b.step("test_artlib", "Create test binaries for debugging 'root'");
    mod_tests_step.dependOn(&install_mod_tests.step);
}

fn buildArm64(b: *std.Build, optimise: std.builtin.OptimizeMode) void {
    std.debug.print(
        "Cannot build for arm64 yet, sorry.",
        .{},
    );
    _ = b;
    _ = optimise;
    return;
}
