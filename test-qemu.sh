#!/bin/bash

#***********************************************************************************************************************
#  ArtInium - Stage-0 Bootloader for RISC-V SoCs
#
# MIT License
#
# Copyright (c) 2026 Artie Poole
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#***********************************************************************************************************************

# ArtInium - QEMU Test Script
# Creates a bootable disk image and runs it in QEMU

set -e

# Add Zig to PATH
export PATH="$HOME/.local/share/zig/0.15.2:$PATH"

echo "Building ArtInium bootloader..."
zig build build_all

echo "Creating bootable disk image..."
# Create a 10MB disk image
dd if=/dev/zero of=disk.img bs=1M count=10

echo "Extracting Stage 1a (first 512 bytes)..."
# Write Stage 1a (MBR) to sector 0 - extract first 512 bytes from file
dd if=zig-out/bin/ArtInium.16 of=disk.img bs=512 count=1 conv=notrunc

echo "Extracting Stage 1b (from file offset 0x400)..."
# Write Stage 1b starting at disk sector 1
# Stage 1b is at file offset 0x400 (1024 bytes) in ArtInium.16
# Write it to disk sector 1 (byte offset 512)
dd if=zig-out/bin/ArtInium.16 of=disk.img bs=512 skip=2 seek=1 conv=notrunc

#echo "Writing Stage 2 (32-bit code) to sector 32..."
# Write Stage 2 (32-bit code) to sector 32 (64KB offset)
dd if=zig-out/bin/ArtInium.32 of=disk.img bs=512 skip=0 seek=17 conv=notrunc 2>/dev/null

echo "Disk image created successfully!"
echo ""
echo "Launching QEMU..."
echo "Press Ctrl+A then X to exit QEMU"
qemu-system-i386 -drive file=disk.img,format=raw -serial file:serial.log -s -S -m 2G -no-reboot -no-shutdown -d int
