const std = @import("std");
const print = std.debug.print;
const e = @import("vk_error.zig");
const vk = @import("vk_c.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

pub const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL_vulkan.h");
});

pub const DeviceQueueIndices = struct {
    graphics: ?u32 = null,
    present: ?u32 = null,

    pub fn isComplete(self: *DeviceQueueIndices) bool {
        _ = self.graphics orelse return false;
        _ = self.present orelse return false;
        return true;
    }
};

pub fn createInstance(allocator: std.mem.Allocator, enable_val: bool, instance: *vkst.Instance) !void {
    const app_info = std.mem.zeroInit(vkst.AppInfo, .{
        .sType = vkcon.ST_APPLICATION_INFO,
        .pApplicationName = "Test",
        .applicationVersion = vkfn.makeVersion(0, 1, 0),
        .pEngineName = "Blackhole",
        .engineVersion = vkfn.makeVersion(0, 0, 1),
        .apiVersion = vkcon.API_1_4,
    });

    var sdl_ext_count: u32 = 0;
    const sdl_extensions: [*]const [*]const u8 = @ptrCast(sdl.SDL_Vulkan_GetInstanceExtensions(&sdl_ext_count).?);
    var required_extensions = try std.ArrayList([*:0]const u8).initCapacity(allocator, sdl_ext_count);
    defer required_extensions.deinit(allocator);

    try required_extensions.appendSlice(allocator, @ptrCast(sdl_extensions[0..sdl_ext_count]));

    var create_info = std.mem.zeroInit(vkst.InstanceCI, .{
        .sType = vkcon.ST_INSTANCE_CI,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @as(u32, @intCast(required_extensions.items.len)),
        .ppEnabledExtensionNames = required_extensions.items.ptr,
        .enabledLayerCount = 0,
    });

    const val_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
    if (enable_val) {
        create_info.enabledLayerCount = val_layers.len;
        create_info.ppEnabledLayerNames = &val_layers;
    }

    const result = vkfn.createInstance(&create_info, null, instance);
    try e.logIfError(result, "Creating Instance");
}

pub fn chooseDevice(allocator: std.mem.Allocator, instance: vkst.Instance, device: *vkst.Device, q_indices: *DeviceQueueIndices) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    var a = arena.allocator();
    defer arena.deinit();

    var device_count: u32 = 0;
    var result = vkfn.enumeratePhysicalDevices(instance, &device_count, null);
    try e.logIfError(result, "Choosing Device");

    if (device_count == 0) {
        return error.VulkanDeviceNotFound;
    }

    var devices = try a.alloc(vkst.PDevice, device_count);

    _ = vkfn.enumeratePhysicalDevices(instance, &device_count, devices.ptr);

    if (devices.len == 0) {
        return error.VulkanDeviceNotPopulated;
    }

    if (devices.len != device_count) {
        return error.VulkanDeviceCountMismatch;
    }

    var d_props: vkst.PDeviceProperties = undefined;
    var d_feats: vkst.PDeviceFeatures = undefined;
    var p_device: ?vkst.PDevice = undefined;
    var high_score: u32 = 0;
    for (devices) |d| {
        var indices = try getDeviceQueueIndices(a, d);
        if (!indices.isComplete()) {
            continue;
        }

        var device_score: u32 = 0;
        vkfn.getDevicePhysicalProperties(d, &d_props);
        vkfn.getDevicePhysicalFeatures(d, &d_feats);

        if (d_props.deviceType == vkcon.PDT_DISCRETE_GPU) {
            device_score += 1000;
        }

        device_score += d_props.limits.maxImageDimension2D;

        if (device_score > high_score) {
            p_device = d;
            q_indices.* = indices;
            high_score = device_score;
        }
    }

    if (high_score == 0) {
        return error.VulkanNoMatchingDevice;
    }

    // queue creation
    const queue_priority: f32 = 1.0;
    const queue_ci: vkst.DeviceQueueCI = .{
        .sType = vkcon.ST_DEVICE_QUEUE_CI,
        .queueFamilyIndex = q_indices.graphics.?,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };

    const device_feats: vkst.PDeviceFeatures = undefined;

    const device_ci: vkst.DeviceCI = .{
        .sType = vkcon.ST_DEVICE_CI,
        .pQueueCreateInfos = &queue_ci,
        .queueCreateInfoCount = 1,
        .pEnabledFeatures = &device_feats,
    };

    result = vkfn.createDevice(p_device.?, &device_ci, null, device);
    try e.logIfError(result, "Creating Logical Device");
}

fn getDeviceQueueIndices(allocator: std.mem.Allocator, device: vkst.PDevice) !DeviceQueueIndices {
    var indices: DeviceQueueIndices = .{
        .graphics = null,
        .present = null,
    };
    var queue_count: u32 = 0;
    vkfn.getPhysicalDeviceQueueFamilyProperties(device, &queue_count, null);

    var queue_properties = try allocator.alloc(vkst.QueueFamilyProperties, queue_count);

    _ = vkfn.getPhysicalDeviceQueueFamilyProperties(device, &queue_count, queue_properties.ptr);

    for (queue_properties, 0..queue_properties.len) |prop, i| {
        if (indices.isComplete()) {
            break;
        }

        if (prop.queueFlags & vkcon.B_QUEUE_GRAPHICS == vkcon.B_QUEUE_GRAPHICS) {
            indices.graphics = @intCast(i);
        }
    }

    return indices;
}
