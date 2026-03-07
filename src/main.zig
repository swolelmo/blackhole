const std = @import("std");
const Io = std.Io;

const blackhole = @import("blackhole");

pub fn main() !void {
    try blackhole.createVulkan();
}
