const vk = @import("vk_c.zig");
const vkfn = vk.functions;
const vkcon = vk.constants;
const vkst = vk.structs;

pub fn transitionImage(
    cmd: vkst.CommandBuffer,
    image: vkst.Image,
    old_layout: vkst.ImageLayout,
    new_layout: vkst.ImageLayout)
{
    var aspect_flags: vkst.ImageAspectFlags = {
        if (new_layout == vkcon.IL_DEPTH_ATTACHMENT_OPTIMAL) {
            vkcon.B_IA_DEPTH
        } else {
            vkcon.B_IA_COLOR
        }
    };

    const barrier: vkst.ImageMemoryBarrier2 = .{
        .sType = vkcon.ST_IMAGE_MEMORY_BARRIER_2,
        .pNext = null,
        .srcStageMask = vkcon.B_PS2_ALL_COMMANDS,
        .srcAccessMask = vkcon.B_A2_MEMORY_WRITE,
        .dstStageMask = vkcon.B_PS2_ALL_COMMANDS,
        .dstAccessMask = vkcon.B_A2_MEMORY_WRITE | vkcon.B_A2_MEMORY_READ,
        .oldLayout = old_layout,
        .newLayout = new_layout,
        .subResourceRange = vkinit.genImageSubresourceRange(aspect_flags),
        .image = image, 
    };

    const dep_info: vkst.DependencyInfo = .{
        .sType = vkcon.ST_DEPENDENCY_INFO,
        .pNext = null,
        .imageMemoryBarrierCount = 1,
        .pImageMemoryBarriers = &barrier,
    };

    vkfn.cmdPipelineBarrier2(cmd, &dep_info);
}
