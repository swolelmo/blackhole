const std = @import("std");
const e = @import("vk_error.zig");
const vk = @import("vk_c.zig");
const vk_init = @import("vk_init.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

pub const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const requiredDeviceExtensions = [*c]const [*c]const u8{vk.extensions.khr_swapchain.name};

var window: ?*sdl.SDL_Window = null;
var instance: vkst.Instance = null;
var surface: vkst.Surface = null;
var device: vkst.Device = null;
var q_indices: DeviceQueueIndices = .{ .graphics = null, .present = null };

pub fn init(allocator: std.mem.Allocator, enable_val: bool) !void {
    const init_flags = sdl.SDL_INIT_VIDEO; 
    if (!sdl.SDL_Init(init_flags)) {
        return error.SDLError;
    }

    window = sdl.SDL_CreateWindow("Testing", 640, 480, sdl.SDL_WINDOW_VULKAN).?;

    try createInstance(allocator, enable_val);

    _ = sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, @ptrCast(&surface));

    try chooseDevice(allocator);
}

pub fn run() !void {
    var should_close = false;
    while (!should_close) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => should_close = true,
                sdl.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        sdl.SDLK_ESCAPE => should_close = true,
                        else => {}
                    }
                },
                else => {},
            }
        }
    }
}

pub fn cleanup() void {
    if (device) |d| {
        vkfn.destroyDevice(d, null);
    }

    if (surface) |s| {
        sdl.SDL_Vulkan_DestroySurface(@ptrCast(instance), @ptrCast(s), null);
    }

    if (instance) |i| {
        vkfn.destroyInstance(i, null);
    }

    if (window) |w| {
        sdl.SDL_DestroyWindow(w);
    }

    sdl.SDL_Quit();
}

const DeviceQueueIndices = struct {
    graphics: ?u32 = null,
    present: ?u32 = null,

    fn isComplete(self: *DeviceQueueIndices) bool {
        _ = self.graphics orelse return false;
        _ = self.present orelse return false;
        return true;
    }
};

fn createInstance(allocator: std.mem.Allocator, enable_val: bool) !void {
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

    const result = vkfn.createInstance(&create_info, null, &instance);
    try e.logIfError(result, "Creating Instance");
}

fn chooseDevice(allocator: std.mem.Allocator) !void {
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
            q_indices = indices;
            high_score = device_score;
        }
    }

    if (high_score == 0) {
        return error.VulkanNoMatchingDevice;
    }

    // queue creation
    const queue_priority: f32 = 1.0;
    const queue_ci: [2]vkst.DeviceQueueCi = undefined;
    const queue_ci[0] = .{
        .sType = vkcon.ST_DEVICE_QUEUE_CI,
        .queueFamilyIndex = q_indices.graphics.?,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };

    const queue_ci[1] = .{
        .sType = vkcon.ST_DEVICE_QUEUE_CI,
        .queueFamilyIndex = q_indices.present.?,
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

    result = vkfn.createDevice(p_device.?, &device_ci, null, &device);
    try e.logIfError(result, "Creating Logical Device");
}

fn getDeviceQueueIndices(allocator: std.mem.Allocator, p_device: vkst.PDevice) !DeviceQueueIndices {
    var indices: DeviceQueueIndices = .{
        .graphics = null,
        .present = null,
    };
    var queue_count: u32 = 0;
    vkfn.getPhysicalDeviceQueueFamilyProperties(p_device, &queue_count, null);

    var queue_properties = try allocator.alloc(vkst.QueueFamilyProperties, queue_count);

    _ = vkfn.getPhysicalDeviceQueueFamilyProperties(p_device, &queue_count, queue_properties.ptr);

    for (queue_properties, 0..queue_properties.len) |prop, i| {
        if (indices.isComplete()) {
            break;
        }

        if (prop.queueFlags & vkcon.B_QUEUE_GRAPHICS == vkcon.B_QUEUE_GRAPHICS) {
            indices.graphics = @intCast(i);
        }

        var present_support: u32 = 0;
        const result = vkfn.getPhysicalDeviceSurfaceSupportKHR(p_device, @intCast(i), surface, &present_support);
        try e.logIfError(result, "Checking Surface Support");
        if (present_support == 1) {
            indices.present = @intCast(i);
        }
    }

    return indices;
}
