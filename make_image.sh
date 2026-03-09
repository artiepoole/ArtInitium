#!/bin/bash
# ArtInitium - QEMU Test Script
# Creates a bootable disk image

set -e

# Add Zig to PATH
export PATH="$HOME/.local/share/zig/0.15.2:$PATH"

echo "Building ArtInitium bootloader..."
zig build build_all


stage1_file="zig-out/bin/ArtInitium.16.x86_32"
stage2_file="zig-out/bin/ArtInitium.32.x86_32"
DISK="artinitium.img"
echo "Creating bootable disk image..."
# Create a 10MB disk image
dd if=/dev/zero of=$DISK bs=1M count=10

echo "Extracting Stage 1a (first 512 bytes)..."
# Write Stage 1a (MBR) to sector 0 - extract first 512 bytes from file
dd if=$stage1_file of=$DISK bs=512 count=1 conv=notrunc

echo "Extracting Stage 1b (from file offset 0x400)..."
# Write Stage 1b starting at disk sector 1
# Stage1b is at file offset 0x400 (1024 bytes) in ArtInitium.16
dd if=$stage1_file of=$DISK bs=512 skip=2 seek=1 conv=notrunc

# Write Stage 2 after Stage1b

total_size=$(stat -c %s "$stage1_file")
stage1b_size=$((total_size - 1024))
stage1b_sectors=$(( (stage1b_size + 511) / 512 ))

echo "Stage1b occupies $stage1b_sectors sectors, Stage 2 will be written after that"

stage2_seek=$(( 1 + stage1b_sectors ))

dd if=$stage2_file of=$DISK bs=512 skip=0 seek=$stage2_seek conv=notrunc 2>/dev/null


# echo "Disk image created successfully!"
# echo ""
# echo "Launching QEMU..."
#
# qemu-system-i386 -drive file=$DISK,format=raw -serial file:serial.log -s -S -m 2G -no-reboot -no-shutdown #-d int
