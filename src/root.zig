//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const print = std.debug.print;

const sdl = @import("sdl/sdl.zig");
const c = sdl.c;
const vke = @import("vulkan/vkengine.zig");

pub fn createVulkan() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var sdlWrapper = try sdl.SdlWrapper.init();
    defer sdlWrapper.destroy();

    try sdlWrapper.createWindow();

    var builder = vke.EngineBuilder.init(
        gpa.allocator(),
        @ptrCast(try sdl.getVulkanLoader()),
        try sdl.getVulkanExtensions());

    _ = builder.withEnableValidation();

    var vkEngine = try builder.build();

    defer vkEngine.destroy();

    var shouldQuit = false;
    while (!shouldQuit) {
        var eventPolled = sdl.pollNextEvent();
        while (eventPolled) |event| : (eventPolled = sdl.pollNextEvent()) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => shouldQuit = true,
                c.SDL_EVENT_KEY_DOWN => {
                    switch (event.key.key) {
                        c.SDLK_ESCAPE => shouldQuit = true,
                        else => {}
                    }
                },
                else => {}
            }
        }
        
    }
}
