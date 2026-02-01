pub const cpu = @import("cpu.zig");
pub const serial = @import("serial.zig");
pub const bios = @import("bios/bios.zig");
pub const debug = @import("debug.zig");
pub const mem = @import("mem/mem.zig");
pub const video = @import("video/video.zig");
pub const io = @import("io/io.zig");
test {
    @import("std").testing.refAllDecls(@This());
}
