const std = @import("std");
const print = std.debug.print;
const e = @import("vk_error.zig");
const vk = @import("vk_c.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

const sdl = @import("..\\sdl\\sdl_c.zig").sdl;

const dev_extensions = [_][]const u8{ vkcon.EN_SWAPCHAIN };
const val_layers = [_][]const u8{"VK_LAYER_KHRONOS_validation"};

pub const DeviceQueueIndices = struct {
    graphics: ?u32 = null,
    present: ?u32 = null,

    pub fn isComplete(self: *DeviceQueueIndices) bool {
        _ = self.graphics orelse return false;
        _ = self.present orelse return false;
        return true;
    }
};

pub fn createInstance(a: std.mem.Allocator, enable_val: bool, instance: *vkst.Instance) !void {
    const app_info = std.mem.zeroInit(vkst.AppInfo, .{
        .sType = vkcon.ST_APPLICATION_INFO,
        .pApplicationName = "Test",
        .applicationVersion = vkfn.makeVersion(0, 1, 0),
        .pEngineName = "Blackhole",
        .engineVersion = vkfn.makeVersion(0, 0, 1),
        .apiVersion = vkcon.API_1_4,
    });

    var sdl_ext_count: u32 = 0;
    const sdl_extensions: [*c]const [*c]const u8 = @ptrCast(sdl.SDL_Vulkan_GetInstanceExtensions(&sdl_ext_count).?);
    var required_extensions = try std.ArrayList([*c]const u8).initCapacity(a, sdl_ext_count);
    defer required_extensions.deinit(a);

    try required_extensions.appendSlice(a, sdl_extensions[0..sdl_ext_count]);

    var create_info = std.mem.zeroInit(vkst.InstanceCI, .{
        .sType = vkcon.ST_INSTANCE_CI,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @as(u32, @intCast(required_extensions.items.len)),
        .ppEnabledExtensionNames = required_extensions.items.ptr,
        .enabledLayerCount = 0,
    });

    if (enable_val) {
        create_info.enabledLayerCount = val_layers.len;
        create_info.ppEnabledLayerNames = @ptrCast(&val_layers);
    }

    const result = vkfn.createInstance(&create_info, null, instance);
    try e.logIfError(result, "Creating Instance");
}

pub fn choosePhysicalDevice(a: std.mem.Allocator, instance: vkst.Instance, surface: vkst.Surface) !vkst.PDevice {
    var device_count: u32 = 0;
    const result = vkfn.enumeratePhysicalDevices(instance, &device_count, null);
    try e.logIfError(result, "Choosing Device");

    if (device_count == 0) {
        return error.VulkanDeviceNotFound;
    }

    var p_devices = try a.alloc(vkst.PDevice, device_count);

    _ = vkfn.enumeratePhysicalDevices(instance, &device_count, p_devices.ptr);

    if (p_devices.len == 0) {
        return error.VulkanDeviceNotPopulated;
    }

    if (p_devices.len != device_count) {
        return error.VulkanDeviceCountMismatch;
    }

    var d_props: vkst.PDeviceProperties = undefined;
    var d_feats: vkst.PDeviceFeatures = undefined;
    var p_device: vkst.PDevice = undefined;
    var high_score: u32 = 0;
    for (p_devices) |pd| {
        var indices = try getDeviceQueueIndices(a, surface, pd);
        if (!indices.isComplete()) {
            continue;
        }

        if (!(try deviceHasExtensions(a, pd))) {
            continue;
        }

        if (!(try deviceHasSurfaceSwapchainSupport(a, surface, pd))) {
            continue;
        }

        var device_score: u32 = 0;
        vkfn.getDevicePhysicalProperties(pd, &d_props);
        vkfn.getDevicePhysicalFeatures(pd, &d_feats);

        if (d_props.deviceType == vkcon.PDT_DISCRETE_GPU) {
            device_score += 1000;
        }

        device_score += d_props.limits.maxImageDimension2D;

        if (device_score > high_score) {
            p_device = pd;
            high_score = device_score;
        }
    }

    if (high_score == 0) {
        return error.VulkanNoMatchingDevice;
    }

    return p_device;
}

pub fn createDevice(p_device: vkst.PDevice, q_indices: DeviceQueueIndices) !vkst.Device {
    // queue creation
    const queue_priority: f32 = 1.0;
    var queue_ci: [2]vkst.DeviceQueueCI = undefined;
    queue_ci[0] = .{
        .sType = vkcon.ST_DEVICE_QUEUE_CI,
        .queueFamilyIndex = q_indices.graphics.?,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };

    queue_ci[1] = .{
        .sType = vkcon.ST_DEVICE_QUEUE_CI,
        .queueFamilyIndex = q_indices.present.?, .queueCount = 1, .pQueuePriorities = &queue_priority,
    };

    const device_feats: vkst.PDeviceFeatures = undefined;

    const device_ci: vkst.DeviceCI = .{
        .sType = vkcon.ST_DEVICE_CI,
        .pQueueCreateInfos = &queue_ci,
        .queueCreateInfoCount = 1,
        .pEnabledFeatures = &device_feats,
        .enabledExtensionCount = dev_extensions.len,
        .ppEnabledExtensionNames = @ptrCast(&dev_extensions),
    };

    var device: vkst.Device = undefined;
    const result = vkfn.createDevice(p_device, &device_ci, null, &device);
    try e.logIfError(result, "Creating Logical Device");

    return device;
}

pub fn createSwapchain(device: vkst.Device, p_device: vkst.PDevice, surface: vkst.Surface, window: *sdl.SDL_Window, q_indices: DeviceQueueIndices) !vkst.Swapchain {
    var capabilities: vkst.SurfaceCapabilities = undefined; 
    var result = vkfn.getPhysicalDeviceSurfaceCapabilities(p_device, surface, &capabilities);
    try e.logIfError(result, "Getting PDevice Surface Capabilities");
    var extent: vkst.Extent2D = undefined;
    if (capabilities.currentExtent.width != std.math.maxInt(i32)) {
        extent = capabilities.currentExtent;
    }
    else {
        var width: i32 = 0;
        var height: i32 = 0;
        if (!sdl.SDL_GetWindowSizeInPixels(window, &width, &height)) {
            return error.SDLGetWindowSizeError;
        }

        extent.width = @intCast(width);
        extent.width = std.math.clamp(
            extent.width,
            capabilities.minImageExtent.width,
            capabilities.maxImageExtent.width);

        extent.height = @intCast(height);
        extent.height = std.math.clamp(
            extent.height,
            capabilities.minImageExtent.height,
            capabilities.maxImageExtent.height);
    }

    var image_count = capabilities.maxImageCount;
    if (image_count == 0) image_count = capabilities.minImageCount + 1;

    var create_info: vkst.SwapchainCI = .{
        .sType = vkcon.ST_SWAPCHAIN_CI,
        .surface = surface,
        .minImageCount = image_count,
        .imageFormat = vkcon.F_B8G8R8A8_SRGB,
        .imageColorSpace = vkcon.CS_SRGB_NONLINEAR,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = vkcon.B_IU_COLOR_ATTACHMENT,
        .imageSharingMode = vkcon.SM_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .preTransform = capabilities.currentTransform,
        .compositeAlpha = vkcon.B_CA_OPAQUE,
        .presentMode = vkcon.PM_MAILBOX,
        .clipped = vkcon.TRUE,
        .oldSwapchain = @ptrCast(vkcon.NULL_HANDLE),
    };

    const q_family_indices: [2]u32 = .{q_indices.graphics.?, q_indices.present.?};
    if (q_family_indices[0] != q_family_indices[1]) {
        create_info.imageSharingMode = vkcon.SM_CONCURRENT;
        create_info.queueFamilyIndexCount = 2;
        create_info.pQueueFamilyIndices = &q_family_indices;
    }

    var swapchain: vkst.Swapchain = undefined;
    result = vkfn.createSwapchain(device, &create_info, null, &swapchain);
    try e.logIfError(result, "Creating Swapchain");

    return swapchain;
}

fn deviceHasExtensions(a: std.mem.Allocator, pd: vkst.PDevice) !bool {
    var extension_count: u32 = 0;
    const result = vkfn.enumerateDeviceExtensionProperties(pd, null, &extension_count, null);
    try e.logIfError(result, "Enumerating Device Extensions");

    var extensions = try a.alloc(vkst.ExtensionProperties, extension_count);
    _ = vkfn.enumerateDeviceExtensionProperties(pd, null, &extension_count, extensions.ptr);
    for (dev_extensions) |d_ext| {
        for (extensions) |ext| {
            if (std.mem.eql(u8, d_ext, std.mem.sliceTo(&ext.extensionName, 0))) {
                break;
            }
        }
        else {
            return false;
        }
    }

    return true;
}

pub fn getDeviceQueueIndices(a: std.mem.Allocator, surface: vkst.Surface, pd: vkst.PDevice) !DeviceQueueIndices {
    var indices: DeviceQueueIndices = .{
        .graphics = null,
        .present = null,
    };
    var queue_count: u32 = 0;
    vkfn.getPhysicalDeviceQueueFamilyProperties(pd, &queue_count, null);

    var queue_properties = try a.alloc(vkst.QueueFamilyProperties, queue_count);

    _ = vkfn.getPhysicalDeviceQueueFamilyProperties(pd, &queue_count, queue_properties.ptr);

    for (queue_properties, 0..queue_properties.len) |prop, i| {
        if (indices.isComplete()) {
            break;
        }

        if (prop.queueFlags & vkcon.B_QUEUE_GRAPHICS == vkcon.B_QUEUE_GRAPHICS) {
            indices.graphics = @intCast(i);
        }

        var present_support: u32 = 0;
        const result = vkfn.getPhysicalDeviceSurfaceSupportKHR(pd, @intCast(i), surface, &present_support);
        try e.logIfError(result, "Checking Surface Support");
        if (present_support == 1) {
            indices.present = @intCast(i);
        }
    }

    return indices;
}

fn deviceHasSurfaceSwapchainSupport(a: std.mem.Allocator, surface: vkst.Surface, pd: vkst.PDevice) !bool {
    var format_count: u32 = 0;
    var result = vkfn.getPhysicalDeviceSurfaceFormats(pd, surface, &format_count, null);
    try e.logIfError(result, "Getting Physical Device Surface Formats");

    var formats = try a.alloc(vkst.SurfaceFormat, format_count);

    _ = vkfn.getPhysicalDeviceSurfaceFormats(pd, surface, &format_count, formats.ptr);

    for (formats) |f| {
        if (f.format == vkcon.F_B8G8R8A8_SRGB
            and f.colorSpace == vkcon.CS_SRGB_NONLINEAR) {
            break;
        }
    }
    else {
        return false;
    }

    var present_mode_count: u32 = 0;
    result = vkfn.getPhysicalDeviceSurfacePresentModes(pd, surface, &present_mode_count, null);
    try e.logIfError(result, "Getting Physical Device Surface Present Modes");

    var present_modes = try a.alloc(vkst.PresentMode, present_mode_count);

    _ = vkfn.getPhysicalDeviceSurfacePresentModes(pd, surface, &present_mode_count, present_modes.ptr);

    for (present_modes) |m| {
        if (m == vkcon.PM_MAILBOX) {
            break;
        }
    }
    else {
        return false;
    }

    return true;
}
