const std = @import("std");
const sdl = @import("sdl");
const vk = @import("vulkan");

const engineName = "blackhole";
const engineVersion = vk.makeApiVersion(0, 0, 1, 0).toU32();
const vulkanApi = vk.API_VERSION_1_3;
const requiredDeviceExtensions = [*c]const [*c]const u8{vk.extensions.khr_swapchain.name};

pub const EngineBuilder = struct {
    allocator: std.mem.Allocator,
    appName: ?[*:0]u8,
    appVersion: u32 = vk.makeApiVersion(0, 0, 1, 0).toU32(),
    procAddress: ?vk.PfnGetInstanceProcAddr,
    extensions: []const [*c]const u8,
    enableValidation: bool,

    pub fn init(
        allocator: std.mem.Allocator,
        procAddress: ?vk.PfnGetInstanceProcAddr,
        extensions: []const [*c]const u8)
    EngineBuilder {
        var builder: EngineBuilder = undefined;
        builder.allocator = allocator;
        builder.procAddress = procAddress;
        builder.extensions = extensions;

        return builder;
    }

    pub fn withAppName(self: *EngineBuilder, name: [*:0]u8) *EngineBuilder {
        self.appName = name;
        return self;
    }

    pub fn withAppVersion(self: *EngineBuilder, version: u32) *EngineBuilder {
        self.appVersion = version;
        return self;
    }

    pub fn withEnableValidation(self: *EngineBuilder) *EngineBuilder {
        self.enableValidation = true;
        return self;
    }

    pub fn build(self: EngineBuilder) !Engine {
        const baseWrapper = vk.BaseWrapper.load(self.procAddress.?);

        const availableLayers = try baseWrapper.enumerateInstanceLayerPropertiesAlloc(self.allocator);
        defer self.allocator.free(availableLayers);

        var requiredLayers: [10][:0]const u8 = undefined;
        var layerCount: u8 = 0;

        const valLayerName = "VK_LAYER_KHRONOS_validation";
        if (self.enableValidation) {
            requiredLayers[layerCount] = valLayerName;
            layerCount += 1;
        }

        for (requiredLayers[0..layerCount]) |requiredLayer| {
            for (availableLayers) |layer| {
                if (std.mem.eql(u8, requiredLayer, std.mem.sliceTo(&layer.layer_name, 0))) {
                    break;
                }
            } else {
                return error.MissingLayer;
            }
        }

        var requiredExtensions: std.ArrayList([*:0]const u8) = .empty;
        defer requiredExtensions.deinit(self.allocator);
        if (self.enableValidation) {
            try requiredExtensions.append(self.allocator, vk.extensions.ext_debug_utils.name);
        }
        try requiredExtensions.append(self.allocator, vk.extensions.khr_portability_enumeration.name);
        try requiredExtensions.append(self.allocator, vk.extensions.khr_get_physical_device_properties_2.name);

        for (self.extensions) |extension| {
            try requiredExtensions.append(self.allocator, extension);
        }

        const appInfo: vk.ApplicationInfo = .{
            .p_application_name = self.appName,
            .application_version = self.appVersion,
            .p_engine_name = engineName,
            .engine_version = engineVersion,
            .api_version = vulkanApi.toU32(),
        };

        const instance = try baseWrapper.createInstance(
            &.{
                .p_application_info = &appInfo,
                .enabled_layer_count = layerCount,
                .pp_enabled_layer_names = @ptrCast(requiredLayers[0..layerCount]),
                .enabled_extension_count = @intCast(requiredExtensions.items.len),
                .pp_enabled_extension_names = requiredExtensions.items.ptr,
                .flags = .{ .enumerate_portability_bit_khr = true },
            }, 
            null);

        const instanceWrapper = vk.InstanceWrapper.load(instance, baseWrapper.dispatch.vkGetInstanceProcAddr.?);
        const instanceProxy = vk.InstanceProxy.init(instance, &instanceWrapper);
        errdefer instanceProxy.destroyInstance(null);

        var debugMessenger: ?vk.DebugUtilsMessengerEXT = null;
        if (self.enableValidation) {
            debugMessenger = try instanceProxy.createDebugUtilsMessengerEXT(&.{
                .message_severity = .{
                    //.verbose_bit_ext = true,
                    //.info_bit_ext = true,
                    .warning_bit_ext = true,
                    .error_bit_ext = true,
                },
                .message_type = .{
                    .general_bit_ext = true,
                    .validation_bit_ext = true,
                    .performance_bit_ext = true,
                },
                .pfn_user_callback = &debugUtilsMessengerCallback,
                .p_user_data = null,
            }, null);
        }

        return .{
            .allocator = self.allocator,
            .baseWrapper = baseWrapper,
            .instanceProxy = instanceProxy,
            .debugMessenger = debugMessenger,
        };
    }
};

pub const Engine = struct {
    allocator: std.mem.Allocator,
    baseWrapper: vk.BaseWrapper,
    instanceProxy: vk.InstanceProxy,
    debugMessenger: ?vk.DebugUtilsMessengerEXT,

    pub fn destroy(self: Engine) void {
        if (self.debugMessenger) |messenger| {
            self.instanceProxy.destroyDebugUtilsMessengerEXT(messenger, null);
        }
        self.instanceProxy.destroyInstance(null);

        self.allocator.destroy(self.instanceProxy.wrapper);
    }
};

fn debugUtilsMessengerCallback(severity: vk.DebugUtilsMessageSeverityFlagsEXT, msgType: vk.DebugUtilsMessageTypeFlagsEXT, callbackData: ?*const vk.DebugUtilsMessengerCallbackDataEXT, _: ?*anyopaque) callconv(.c) vk.Bool32 {
    const severityStr =
        if (severity.verbose_bit_ext) "verbose" 
        else if (severity.info_bit_ext) "info"
        else if (severity.warning_bit_ext) "warning"
        else if (severity.error_bit_ext) "error"
        else "unknown";

    const typeStr =
        if (msgType.general_bit_ext) "general"
        else if (msgType.validation_bit_ext) "validation"
        else if (msgType.performance_bit_ext) "performance"
        else if (msgType.device_address_binding_bit_ext) "device addr"
        else "unknown";

    const message: [*c]const u8 =
        if (callbackData) |cbData| cbData.p_message
        else "NO MESSAGE!";

    std.debug.print("[{s}][{s}]. Message:\n  {s}\n", .{ severityStr, typeStr, message });

    return .false;
}
