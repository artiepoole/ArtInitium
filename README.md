# ArtInitium - Custom Bootloader for QEMU

Written for academic purposes in Zig 0.15.2 and various forms of assembly.

## Overview

ArtInitium is a multi-stage bootloader. It is designed to be simple and educational, demonstrating the boot process and basic hardware interactions without relying on complex bootloaders like GRUB.
The main goal is to be cross_platform to demonstrate Zig's power in this domain, but currently it only supports x86_32.
Future plans include adding support for x86_64, ARM 32, ARM 64 and RISC-V.
In x86_32 it replaces GRUB for QEMU.
For this architecture it demonstrates the complete boot process from BIOS handoff to protected mode kernel loading.

## Building

The build system has been configured such that any combination of architectures and output file formats can be specified as comma separated lists of options. By default, "none" is selected and so you must specify at least one option for architectures and outputs. See below for the usage

```shell 
zig build [-Darchitectures=<none|x86_32|arm64|all>] [-Doutputs=<none|elf|bin|img|all>]
```

Below is an example which will build for all architectures and "install" the images and ELF (containing debug information) files to `zig-out/<ext>/ArtInitium.<arch>.<ext>`. Note that for x86_32 and x86_64 architectures, there will be several binaries and two elfs. This is because those architectures start in a 16-bit only mode (real mode), before progressing to higher levels (such as 32-bit (protected mode) before 64-bit (long mode) for x86_64).

```shell
zig build -Darchitectures=all -Doutputs=img,elf
```

Note that if you specify "none,<anything_else>", none will take the lowest precedence, and similarly all will override any speficied option.

## Architecture Naming

ArtInitium uses the following architecture names:

| Name      | Description                                      | QEMU Binary (Ubuntu Noble) |
|-----------|--------------------------------------------------|----------------------------|
| `x86_32`  | i386/i686 family of 32-bit x86 architecture CPUs | `qemu-system-i386`         |
| `x86_64`  | x64/AMD64 family of 64-bit x86 architecture CPUs | `qemu-system-x86_64`       |
| `arm32`   | Any 32-bit ARM CPU, such as ARMv7-A              | `qemu-system-arm`          |
| `arm64`   | AArch64 family, i.e. any 64-bit ARM CPU          | `qemu-system-aarch64`      |
| `riscv32` | 32-bit RISC-V (RV32)                             | `qemu-system-riscv32`      |
| `riscv64` | 64-bit RISC-V (RV64)                             | `qemu-system-riscv64`      |

I chose these names for clarity and consistency, going against the names used by the big players, such as Linux.

The actual support list for ArtInitium is likely to be very limited, so expect only the default configurations for each QEMU version to be supported, and expect only single CPU and single core operation within this project.

## ArtInitium for x86_32

The x86_32 architecture implementation is as minimal as possible, with no intention to implement sophisticated features. This is because the author has "been there, done that, got the job". See [ArtOS](https://github.com/artiepoole/artos) for more on that.

### Architecture for x86_32

#### Stage 1a (512 bytes @ 0x7C00)

- MBR boot sector loaded by BIOS
- Enables A20 line for >1MB memory access
- Loads Stage 1b from disk using BIOS INT 13h
- Jumps to Stage 1b at 0x8000

#### Stage 1b (up to 4KB @ 0x8000)

- **Hello World message** - Displays boot message via BIOS INT 10h
- **E820 memory map** - Collects system memory layout from BIOS
- **VGA/VBE detection** - Queries available VBE modes (doesn't set mode yet)
- **Boot info preparation** - Prepares structure with memory map and VBE mode info
- **Protected mode transition** - Sets up GDT and switches to 32-bit mode
- Jumps to Stage 2 at 0x10000

#### Stage 2 (@ 0x10000 / 64KB)

- 32-bit protected mode code (written in Zig)
- **Video mode setup** - Uses Bochs VBE extensions to set graphics mode in protected mode
- Will contain storage drivers (IDE, AHCI, etc.)
- Loads and launches the kernel
- Currently: demonstrates video mode switching using boot info from Stage 1b

### Building x86_32 image for qemu

```shell
# Make sure Zig 0.15.2 is in PATH or use the test script
zig build -Darchitectures=x86_32 -Doutputs=img
```

or if you want to debug etc use

```shell
zig build -Darchitectures=x86_32 -Doutputs=img,elf
```

### Testing x86_32

```shell
# Run in QEMU with the built image
./make_image.sh
qemu-system-i386 -drive file=artinitium.img,format=raw -serial file:serial.log -serial stdio -s -S -m 2G -no-reboot -no-shutdown
```

## Dependencies

### qemu and normal build tools

I am running qemu-system-i386 for testing and normal build tools like make, gcc, etc. for building the stages. You can install them on Ubuntu with:

```shell
sudo apt install qemu-system-x86 build-essential
```

### device-tree-compiler (dtc)

I use dtc to compile the image definition into a dtb for parsing with binman. You can install it on Ubuntu with:

```
sudo apt install device-tree-compiler
```

### binman from u-boot

For image building, I am using u-boot's [binman](https://docs.u-boot.org/en/latest/develop/package/binman.html) tool. The easiest way to install it on Ubuntu is via pip/pipx:

```shell
pipx install binary-manager
```

but there was a dependency or import issue which I fixed on ubuntu with the patch below. If you have the same issue, you can apply the patch below to your pipx installation. The file to patch is likely located at `~/.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py` but it may be different based on your python version and pipx configuration.

e.g. command to apply patch:

```shell
patch /home/artiepoole/.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py < control_py_fix.patch 
```

It can be used/built from source as well, but I haven't tested that process. If you want to do that, clone the u-boot repo and follow the instructions in the link above.

<details>
<summary>control.py patch</summary>

```diff
Index: ../../.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py
IDEA additional info:
Subsystem: com.intellij.openapi.diff.impl.patch.CharsetEP
<+>UTF-8
===================================================================
diff --git a/../../.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py b/../../.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py
--- a/../../.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py
+++ b/../../.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py
@@ -13,7 +13,6 @@
     # for Python 3.6
     import importlib_resources
 import os
-import pkg_resources
 import re
 
 import sys
@@ -95,7 +94,7 @@
             msg = ''
         return tag, msg
 
-    my_data = pkg_resources.resource_string(__name__, 'missing-blob-help')
+    my_data = importlib.resources.files(__name__).joinpath('missing-blob-help').read_bytes()
     re_tag = re.compile('^([-a-z0-9]+):$')
     result = {}
     tag = None
@@ -150,7 +149,7 @@
     Returns:
         Set of paths to entry class filenames
     """
-    glob_list = pkg_resources.resource_listdir(__name__, 'etype')
+    glob_list = [f.name for f in importlib.resources.files(__name__).joinpath('etype').iterdir()]
     glob_list = [fname for fname in glob_list if fname.endswith('.py')]
     return set([os.path.splitext(os.path.basename(item))[0]
                 for item in glob_list
```

</details>

## ArtInitium for Arm

There are currently no plans to support custom feature sets of Arm CPUs at the time of writing. 
The most "default" configuration will be used to launch the QEMU instance, and this is what will be supported.

## ArtInitium for riscv

There is a plan to have a fully customisable system where features can be toggled on and off using zig CPU features support. 
These will be passed either as additional arguments to the build call, or there will be some other config system at play.
This is not going to be done for a long time. Until then, even floating points will not be supported until absolutely necessary.
