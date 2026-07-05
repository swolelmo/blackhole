const std = @import("std");
const e = @import("vk_error.zig");
const vk = @import("vk_c.zig");
const vkinit = @import("vk_init.zig");
const com = @import("vk_common.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

const sdl = @import("..\\sdl\\sdl_c.zig").sdl;

const dev_extensions = [_][]const u8{ vkcon.EN_SWAPCHAIN };
const val_layers = [_][]const u8{"VK_LAYER_KHRONOS_validation"};

var arena: std.heap.ArenaAllocator = undefined;
var allocator: ?std.mem.Allocator = null;
var window: ?*sdl.SDL_Window = null;
var instance: vkst.Instance = null;
var surface: vkst.Surface = null;
var p_device: vkst.PDevice = null;
var device: vkst.Device = null;
var q_indices: com.DeviceQueueIndices = .{ .graphics = null, .present = null };
var q_graphics: vkst.Queue = null;
var q_present: vkst.Queue = null;
var swapchain: com.SwapchainData = .{
    .swapchain = null,
    .extent = undefined,
    .images = undefined,
    .image_views = undefined,
    .frames = undefined,
    .num_images = 0,
    .cur_frame = 0,
};

pub fn init(a: std.mem.Allocator, enable_val: bool) !void {
    arena = std.heap.ArenaAllocator.init(a);
    allocator = arena.allocator();

    const init_flags = sdl.SDL_INIT_VIDEO; 
    if (!sdl.SDL_Init(init_flags)) {
        return error.SDLInitError;
    }

    window = sdl.SDL_CreateWindow("Testing", 640, 480, sdl.SDL_WINDOW_VULKAN).?;

    try vkinit.createInstance(allocator.?, enable_val, &instance);

    if (!sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, @ptrCast(&surface))) {
        return error.SDLSurfaceCreateError;
    }

    p_device = try vkinit.choosePhysicalDevice(allocator.?, instance, surface);
    q_indices = try vkinit.getDeviceQueueIndices(allocator.?, surface, p_device);
    device = try vkinit.createDevice(p_device, q_indices);
    vkfn.getDeviceQueue(device, q_indices.graphics.?, 0, &q_graphics);
    vkfn.getDeviceQueue(device, q_indices.present.?, 0, &q_present);
    swapchain = try vkinit.createSwapchain(device, p_device, surface, window.?, q_indices);
    try vkinit.createCommands(device, q_indices.graphics.?, &swapchain);
}

pub fn run() !void {
    var should_close = false;
    while (!should_close) {
        std.debug.print("Draw\n", .{});
        try draw();
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

pub fn draw() !void {
    var frame = swapchain.frames[swapchain.cur_frame % 2];
    var result = vkfn.waitForFences(device, 1, &frame.render_fence, vkcon.TRUE, 1000000);
    try e.logIfError(result, "Waiting for render fence");

    result = vkfn.resetFences(device, 1, &frame.render_fence);
    try e.logIfError(result, "Resetting render fence");

    var image_index: u32 = 0;
    result = vkfn.acquireNextImage(device, swapchain.swapchain, 1000000, frame.swapchain_semaphore, null, &image_index);

    const cmd = frame.command_buffer; 
    result = vkfn.resetCommandBuffer(cmd, 0);
    try e.logIfError(result, "Resetting command buffer");

    const cmd_bi = vkinit.genCommandBufferBeginInfo(vkcon.B_CBU_ONE_TIME_SUBMIT);
    result = vkfn.beginCommandBuffer(cmd, &cmd_bi);
    try e.logIfError(result, "Beginning command buffer");
}

pub fn cleanup() void {
    for (0..swapchain.frames.len) |i| {
        vkfn.destroyCommandPool(device, swapchain.frames[i].command_pool, null);
        vkfn.destroyFence(device,swapchain.frames[i].render_fence, null);
        vkfn.destroySemaphore(device,swapchain.frames[i].render_semaphore, null);
        vkfn.destroySemaphore(device,swapchain.frames[i].swapchain_semaphore, null);
    }

    if (swapchain.swapchain) |s| {
        for (0..swapchain.num_images) |i| {
            vkfn.destroyImageView(device, swapchain.image_views[i], null);
        }

        vkfn.destroySwapchain(device, s, null);
    }

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

    arena.deinit();
}
