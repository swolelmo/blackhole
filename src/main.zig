const std = @import("std");
const print = std.debug.print;
const Io = std.Io;

const blackhole = @import("blackhole");

pub fn main() !void {
    try blackhole.createVulkan();
}
