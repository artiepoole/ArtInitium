// ArtInitium - AArch64 Stage 1 Entry Point
// Loaded by QEMU at 0x40000000 (virt machine)
// Execution begins in AArch64 EL1 or EL2

const std = @import("std");

/// Entry point - must be the first symbol in the binary
/// QEMU virt machine jumps here after "BIOS" initialisation
pub export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\.section .text.boot, "ax", %progbits
        \\.global _start
        // Save DTB address passed by QEMU in x0 before we clobber it
        \\  mov x19, x0
        // Determine which Exception Level we are in
        // EL2 is common when launched with default QEMU flags
        \\  mrs x0, CurrentEL
        \\  lsr x0, x0, #2
        \\  and x0, x0, #0b11
        \\  cmp x0, #2
        \\  b.ne .common_setup // If not EL2, assume EL1 and jump to common setup

    // EL2 setup - drop to EL1
        \\.el2_setup:
        // Disable EL2 traps on FP/SIMD
        \\  mov x0, #0x33FF
        \\  msr cptr_el2, x0
        // Set EL1 execution state to AArch64
        \\  mov x0, #(1 << 31)
        \\  msr hcr_el2, x0
        // Set up SPSR_EL2 to return to EL1h with interrupts masked
        \\  mov x0, #0x3C5
        \\  msr spsr_el2, x0
        // Set ELR_EL2 to common_setup so eret drops us to EL1
        \\  adr x0, .common_setup
        \\  msr elr_el2, x0
        \\  eret

        \\.common_setup:
        // Ensure all other cores are parked (only core 0 continues)
        \\  mrs x0, mpidr_el1
        \\  and x0, x0, #0xFF
        \\  cbnz x0, .park

    // Set up the stack pointer
    // Stack grows downward from __stack_top, which is defined in the linker script
    // stack is 64 KB, so __stack_top is 64 KB after bss_end
        \\  adr x0, __stack_top
        \\  mov sp, x0

    // Zero out the BSS section
        \\  adr x0, __bss_start
        \\  adr x1, __bss_end
        \\.bss_zero_loop:
        \\  cmp x0, x1
        \\  b.ge .bss_done
        \\  str xzr, [x0], #8
        \\  b .bss_zero_loop
        \\.bss_done:

    // Jump to the Zig main stage function, passing DTB address as first argument
        \\  mov x0, x19
        \\  bl ArtInitium_entry

    // Should never return, but park if it does
        \\.park:
        \\  wfe
        \\  b .park
    );
}
