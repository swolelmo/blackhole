const vk = @import("vk_c.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

pub const DeviceQueueIndices = struct {
    graphics: ?u32 = null,
    present: ?u32 = null,

    pub fn isComplete(self: *DeviceQueueIndices) bool {
        _ = self.graphics orelse return false;
        _ = self.present orelse return false;
        return true;
    }
};

pub const FrameData = struct {
    command_pool: vkst.CommandPool = null,
    command_buffer: vkst.CommandBuffer = null,
    swapchain_semaphore: vkst.Semaphore = undefined,
    render_semaphore: vkst.Semaphore = undefined,
    render_fence: vkst.Fence = undefined,
};

pub const SwapchainData = struct {
    swapchain: vkst.Swapchain = undefined,
    extent: vkst.Extent2D = undefined,
    frames: [2]FrameData = undefined,
    images: [3]vkst.Image = undefined,
    image_views: [3]vkst.ImageView = undefined,
    num_images: u8 = 0,
    cur_frame: u16 = 0,
};
