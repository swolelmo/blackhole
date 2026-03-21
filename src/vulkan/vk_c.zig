const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const functions = struct {
    pub const makeVersion = c.VK_MAKE_VERSION;
    pub const createInstance = c.vkCreateInstance;
    pub const destroyInstance = c.vkDestroyInstance;
    pub const enumeratePhysicalDevices = c.vkEnumeratePhysicalDevices;
    pub const getDevicePhysicalProperties = c.vkGetPhysicalDeviceProperties;
    pub const getDevicePhysicalFeatures = c.vkGetPhysicalDeviceFeatures;
    pub const getPhysicalDeviceQueueFamilyProperties = c.vkGetPhysicalDeviceQueueFamilyProperties;
    pub const createDevice = c.vkCreateDevice;
    pub const destroyDevice = c.vkDestroyDevice;
};

pub const structs = struct {
    pub const AppInfo = c.VkApplicationInfo;
    pub const Instance = c.VkInstance;
    pub const InstanceCI = c.VkInstanceCreateInfo;
    pub const PDevice = c.VkPhysicalDevice;
    pub const PDeviceProperties = c.VkPhysicalDeviceProperties;
    pub const PDeviceFeatures = c.VkPhysicalDeviceFeatures;
    pub const QueueFamilyProperties = c.VkQueueFamilyProperties;
    pub const DeviceQueueCI = c.VkDeviceQueueCreateInfo;
    pub const DeviceCI = c.VkDeviceCreateInfo;
    pub const Device = c.VkDevice;
    pub const Result = c.VkResult;
};

pub const constants = struct {
    pub const API_1_4 = c.VK_API_VERSION_1_4;

    // Structure Types
    pub const ST_APPLICATION_INFO = c.VK_STRUCTURE_TYPE_APPLICATION_INFO;
    pub const ST_INSTANCE_CI = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    pub const ST_DEVICE_QUEUE_CI = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    pub const ST_DEVICE_CI = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;

    // VK_Results
    pub const SUCCESS = c.VK_SUCCESS;

    // Extension Names
    pub const EN_DEBUG_UTILS = c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME;

    // Physical Device Types
    pub const PDT_DISCRETE_GPU = c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;

    // Queue bits
    pub const B_QUEUE_GRAPHICS = c.VK_QUEUE_GRAPHICS_BIT;
};
