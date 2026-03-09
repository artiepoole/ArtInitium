# ArtInitium

Custom x86_32 Bootloader for QEMU - A GRUB Replacement

Written for Academic Purposes in AT&T Assembly and Zig 0.15.2

## Overview

ArtInitium is a multi-stage bootloader. It is designed to be simple and educational, demonstrating the boot process and basic hardware interactions without relying on complex bootloaders like GRUB.
The main goal is to be cross_platform to demonstrate Zig's power in this domain, but currently it only supports x86_32. 
Future plans include adding support for x86_64, ARM 32 and 64 and RISC-V.
In x86_32 it replaces GRUB for Qemu. 
For this architecture it demonstrates the complete boot process from BIOS handoff to protected mode kernel loading.

## ArtInitium for x86_32

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

### Building x86_32

```bash
# Make sure Zig 0.15.2 is in PATH or use the test script
zig build build_all
```

### Testing x86_32

```bash
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
```bash
pipx install binary-manager
```
but there was a dependency or import issue which I fixed on ubuntu with the patch below. If you have the same issue, you can apply the patch below to your pipx installation. The file to patch is likely located at `~/.local/share/pipx/venvs/binary-manager/lib/python3.12/site-packages/binman/control.py` but it may be different based on your python version and pipx configuration.

e.g. command to apply patch:
```bash
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
