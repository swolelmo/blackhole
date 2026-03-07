const e = @import("error.zig");
pub const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

pub const SdlWrapper = struct {
    initFlags: c.SDL_InitFlags,
    window: ?*c.SDL_Window,

    pub fn init() !SdlWrapper {
        const initFlags = c.SDL_INIT_VIDEO; 
        try e.errorConvert(c.SDL_Init(initFlags));

        return .{
            .initFlags = initFlags,
            .window = null,
        };
    }

    pub fn createWindow(self: *SdlWrapper) !void {
        self.window = try e.errorConvert(c.SDL_CreateWindow(
                "Testing",
                640,
                480,
                c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_VULKAN));
    }


    pub fn destroy(self: SdlWrapper) void {
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
};

pub fn pollNextEvent() ?c.SDL_Event {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(@ptrCast(&event))) {
        return event;
    }

    return null;
}

pub fn getVulkanLoader() !c.SDL_FunctionPointer {
    return try e.errorConvert(c.SDL_Vulkan_GetVkGetInstanceProcAddr());
}

pub fn getVulkanExtensions() ![*c]const [*c]const u8{
    var count: u32 = 0;
    return try e.errorConvert(c.SDL_Vulkan_GetInstanceExtensions(&count));
}
