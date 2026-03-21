const std = @import("std");
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

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: *sdl.SDL_Window,
    instance: vkst.Instance,
    device: vk_init.Device,

    pub fn init(allocator: std.mem.Allocator, enable_val: bool) !Engine {
        const init_flags = sdl.SDL_INIT_VIDEO; 
        if (!sdl.SDL_Init(init_flags)) {
            return error.SDLError;
        }

        const window = sdl.SDL_CreateWindow("Testing", 641, 480, sdl.SDL_WINDOW_VULKAN).?;

        const instance = try vk_init.createInstance(allocator, enable_val);

        const device = try vk_init.chooseDevice(allocator, instance);
        
        return .{
            .allocator = allocator,
            .window = window,
            .instance = instance,
            .device = device,
        };
    }

    pub fn run(_: *Engine) !void {
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

    pub fn cleanup(self: *Engine) void {
        vkfn.destroyDevice(self.device.device, null);
        vkfn.destroyInstance(self.instance, null);
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }
};
