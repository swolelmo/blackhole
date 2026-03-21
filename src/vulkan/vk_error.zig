const std = @import("std");

const vk = @import("vk_c.zig");
const vkst = vk.structs;
const vkcon = vk.constants;

pub fn logIfError(result: vkst.Result, message: []const u8) !void {
    switch (result) {
        vkcon.SUCCESS => return,
        else => {
            std.debug.print("Vulkan Error {d} | {s}", .{ result, message });
            return error.VulkanError;
        }
    }
}
