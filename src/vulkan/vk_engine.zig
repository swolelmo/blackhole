const std = @import("std");
const e = @import("vk_error.zig");
const vk = @import("vk_c.zig");
const vkinit = @import("vk_init.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

const sdl = @import("..\\sdl\\sdl_c.zig").sdl;

const dev_extensions = [_][]const u8{ vkcon.EN_SWAPCHAIN };
const val_layers = [_][]const u8{"VK_LAYER_KHRONOS_validation"};

var window: ?*sdl.SDL_Window = null;
var instance: vkst.Instance = null;
var surface: vkst.Surface = null;
var p_device: vkst.PDevice = null;
var device: vkst.Device = null;
var q_indices: vkinit.DeviceQueueIndices = .{ .graphics = null, .present = null };
var q_graphics: vkst.Queue = null;
var q_present: vkst.Queue = null;
var swapchain: vkst.Swapchain = null;

pub fn init(allocator: std.mem.Allocator, enable_val: bool) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    const a = arena.allocator();
    defer arena.deinit();

    const init_flags = sdl.SDL_INIT_VIDEO; 
    if (!sdl.SDL_Init(init_flags)) {
        return error.SDLInitError;
    }

    window = sdl.SDL_CreateWindow("Testing", 640, 480, sdl.SDL_WINDOW_VULKAN).?;

    try vkinit.createInstance(a, enable_val, &instance);

    if (!sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, @ptrCast(&surface))) {
        return error.SDLSurfaceCreateError;
    }

    p_device = try vkinit.choosePhysicalDevice(a, instance, surface);
    q_indices = try vkinit.getDeviceQueueIndices(a, surface, p_device);
    device = try vkinit.createDevice(p_device, q_indices);
    vkfn.getDeviceQueue(device, q_indices.graphics.?, 0, &q_graphics);
    vkfn.getDeviceQueue(device, q_indices.present.?, 0, &q_present);
    swapchain = try vkinit.createSwapchain(device, p_device, surface, window.?, q_indices);
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
    if (swapchain) |s| {
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
}
