const std = @import("std");
const print = std.debug.print;
const e = @import("vk_error.zig");
const com = @import("vk_common.zig");
const vk = @import("vk_c.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

const sdl = @import("..\\sdl\\sdl_c.zig").sdl;

const dev_extensions = [_][]const u8{ vkcon.EN_SWAPCHAIN };
const val_layers = [_][]const u8{"VK_LAYER_KHRONOS_validation"};
pub const num_frame_buffers = 3;
const image_format = vkcon.F_B8G8R8A8_SRGB;
const image_color = vkcon.CS_SRGB_NONLINEAR;

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

pub fn createDevice(p_device: vkst.PDevice, q_indices: com.DeviceQueueIndices) !vkst.Device {
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

pub fn createSwapchain(device: vkst.Device, p_device: vkst.PDevice, surface: vkst.Surface, window: *sdl.SDL_Window, q_indices: com.DeviceQueueIndices) !com.SwapchainData {
    var to_return: com.SwapchainData = undefined;
    var capabilities: vkst.SurfaceCapabilities = undefined; 
    var result = vkfn.getPhysicalDeviceSurfaceCapabilities(p_device, surface, &capabilities);
    try e.logIfError(result, "Getting PDevice Surface Capabilities");
    if (capabilities.currentExtent.width != std.math.maxInt(i32)) {
        to_return.extent = capabilities.currentExtent;
    }
    else {
        var width: i32 = 0;
        var height: i32 = 0;
        if (!sdl.SDL_GetWindowSizeInPixels(window, &width, &height)) {
            return error.SDLGetWindowSizeError;
        }

        to_return.extent.width = @intCast(width);
        to_return.extent.width = std.math.clamp(
            to_return.extent.width,
            capabilities.minImageExtent.width,
            capabilities.maxImageExtent.width);

        to_return.extent.height = @intCast(height);
        to_return.extent.height = std.math.clamp(
            to_return.extent.height,
            capabilities.minImageExtent.height,
            capabilities.maxImageExtent.height);
    }

    to_return.num_images = 3;
    if (to_return.num_images > capabilities.maxImageCount) {
        to_return.num_images = 2;
        if (to_return.num_images > capabilities.maxImageCount) {
            return error.NotEnoughImages;
        }
    }

    var create_info: vkst.SwapchainCI = .{
        .sType = vkcon.ST_SWAPCHAIN_CI,
        .surface = surface,
        .minImageCount = to_return.num_images,
        .imageFormat = image_format,
        .imageColorSpace = image_color,
        .imageExtent = to_return.extent,
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

    result = vkfn.createSwapchain(device, &create_info, null, &to_return.swapchain);
    try e.logIfError(result, "Creating Swapchain");

    var image_count: u32 = 0;
    result = vkfn.getSwapchainImages(device, to_return.swapchain, &image_count, null);
    try e.logIfError(result, "Getting Swapchain Images");
    if (image_count > 3) {
        return error.TooManyImages;
    }

    _ = vkfn.getSwapchainImages(device, to_return.swapchain, &image_count, &to_return.images);

    var image_view_ci: vkst.ImageViewCI = .{
        .sType = vkcon.ST_IMAGE_VIEW_CI,
        .viewType = vkcon.IVT_2D,
        .format = image_format,
        .components = .{
            .r = vkcon.COMPONENT_SWIZZLE_IDENTITY,
            .g = vkcon.COMPONENT_SWIZZLE_IDENTITY,
            .b = vkcon.COMPONENT_SWIZZLE_IDENTITY,
            .a = vkcon.COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = .{
            .aspectMask = vkcon.B_IA_COLOR,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
    };

    for (0..image_count) |i| {
        image_view_ci.image = to_return.images[i];
        result = vkfn.createImageView(device, &image_view_ci, null, &to_return.image_views[i]);
        try e.logIfError(result, "Creating Image View");
    }

    return to_return;
}

pub fn createCommands(device: vkst.Device, graphics_queue_index: u32, swapchain: *com.SwapchainData) !void {
    const command_pool_ci = std.mem.zeroInit(
        vkst.CommandPoolCI,
        .{
            .sType = vkcon.ST_COMMAND_POOL_CI,
            .pNext = null,
            .queueFamilyIndex = graphics_queue_index,
            .flags = vkcon.B_CPC_RESET_COMMAND_BUFFER,
        });

    const fence_ci = genFenceCI(vkcon.B_FC_SIGNALED);
    const semaphore_ci = genSemaphoreCI(0);

    for (0..swapchain.frames.len) |i| {
        var result = vkfn.createCommandPool(device, &command_pool_ci, null, @constCast(&swapchain.frames[i].command_pool));
        try e.logIfError(result, "Creating Command pool");

        const buffer_ai = std.mem.zeroInit(
            vkst.CommandBufferAI,
            .{
                .sType = vkcon.ST_COMMAND_BUFFER_AI,
                .pNext = null,
                .commandPool = swapchain.frames[i].command_pool,
                .commandBufferCount = 1,
                .level = vkcon.CBL_PRIMARY,
            });


        result = vkfn.allocateCommandBuffers(device, &buffer_ai, @constCast(&swapchain.frames[i].command_buffer));
        try e.logIfError(result, "Allocating Command Buffers");

        result = vkfn.createFence(device, &fence_ci, null, &swapchain.frames[i].render_fence);
        try e.logIfError(result, "Creating Render Fence");

        result = vkfn.createSemaphore(device, &semaphore_ci, null, &swapchain.frames[i].render_semaphore);
        try e.logIfError(result, "Creating Render Semaphore");

        result = vkfn.createSemaphore(device, &semaphore_ci, null, &swapchain.frames[i].swapchain_semaphore);
        try e.logIfError(result, "Creating Swapchain Semaphore");
    }
}

fn genCommandPoolCI(queue_index: u32, flags: u32) vkst.CommandPoolCI {
    return std.mem.zeroInit(
        vkst.CommandPoolCI,
        .{
            .sType = vkcon.ST_COMMAND_POOL_CI,
            .pNext = null,
            .queueFamilyIndex = queue_index,
            .flags = flags,
        });
}

fn genCommandBufferAI(pool: vkst.CommandPool, count: u32) vkst.CommandBufferAI {
    return std.mem.zeroInit(
        vkst.CommandBufferAI,
        .{
            .sType = vkcon.ST_COMMAND_BUFFER_AI,
            .pNext = null,
            .commandPool = pool,
            .commandBufferCount = count,
            .level = vkcon.CBL_PRIMARY,
        });
}

fn genSemaphoreCI(flags: u32) vkst.SemaphoreCI {
    return .{
        .sType = vkcon.ST_SEMAPHORE_CI,
        .pNext = null,
        .flags = flags,
    };
}

fn genFenceCI(flags: u32) vkst.FenceCI {
    return .{
        .sType = vkcon.ST_FENCE_CI,
        .pNext = null,
        .flags = flags,
    };
}

pub fn genCommandBufferBeginInfo(flags: vkst.CommandBufferUsageFlags) vkst.CommandBufferBI {
    const info: vkst.CommandBufferBI = .{
        .sType = vkcon.ST_COMMAND_BUFFER_BI,
        .pNext = null,
        .pInheritanceInfo = null,
        .flags = flags
    };

    return info;
}

pub fn genImageSubresourceRange(aspect_flags: vkst.ImageAspectFlags) vkst.ImageSubresourceRange {
    const sub_range: vkst.ImageSubresourceRange = .{
        .aspectMask = aspect_flags,
        .baseMipLevel = 0,
        .levelCount = vkcon.REMAINING_MIP_LEVELS,
        .baseArrayLayers = 0,
        .layerCount = vkcon.REMAINING_ARRAY_LAYERS,
    };

    return sub_range;
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

pub fn getDeviceQueueIndices(a: std.mem.Allocator, surface: vkst.Surface, pd: vkst.PDevice) !com.DeviceQueueIndices {
    var indices: com.DeviceQueueIndices = .{
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
        if (f.format == image_format
            and f.colorSpace == image_color) {
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
