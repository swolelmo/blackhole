//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const print = std.debug.print;

const vke = @import("vulkan/vk_engine.zig");

pub fn createVulkan() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try vke.init(gpa.allocator(), true);
    defer vke.cleanup();

    try vke.run();
}
