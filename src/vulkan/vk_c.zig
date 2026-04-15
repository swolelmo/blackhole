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
    pub const getPhysicalDeviceSurfaceSupportKHR = c.vkGetPhysicalDeviceSurfaceSupportKHR;
    pub const getDeviceQueue = c.vkGetDeviceQueue;
    pub const enumerateDeviceExtensionProperties = c.vkEnumerateDeviceExtensionProperties;
    pub const getPhysicalDeviceSurfaceCapabilities = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR;
    pub const getPhysicalDeviceSurfaceFormats = c.vkGetPhysicalDeviceSurfaceFormatsKHR;
    pub const getPhysicalDeviceSurfacePresentModes = c.vkGetPhysicalDeviceSurfacePresentModesKHR;
    pub const createSwapchain = c.vkCreateSwapchainKHR;
    pub const destroySwapchain = c.vkDestroySwapchainKHR;
    pub const getSwapchainImages = c.vkGetSwapchainImagesKHR;
    pub const createImageView = c.vkCreateImageView;
    pub const destroyImageView = c.vkDestroyImageView;
    pub const createCommandPool = c.vkCreateCommandPool;
    pub const allocateCommandBuffers = c.vkAllocateCommandBuffers;
    pub const destroyCommandPool = c.vkDestroyCommandPool;
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
    pub const Surface = c.VkSurfaceKHR;
    pub const Result = c.VkResult;
    pub const Bool = c.VkBool32;
    pub const Queue = c.VkQueue;
    pub const ExtensionProperties = c.VkExtensionProperties;
    pub const SurfaceCapabilities = c.VkSurfaceCapabilitiesKHR;
    pub const SurfaceFormat = c.VkSurfaceFormatKHR;
    pub const PresentMode = c.VkPresentModeKHR;
    pub const Extent2D = c.VkExtent2D;
    pub const SwapchainCI = c.VkSwapchainCreateInfoKHR;
    pub const Swapchain = c.VkSwapchainKHR;
    pub const Image = c.VkImage;
    pub const ImageView = c.VkImageView;
    pub const ImageViewCI = c.VkImageViewCreateInfo;
    pub const CommandPoolCI = c.VkCommandPoolCreateInfo;
    pub const CommandPool = c.VkCommandPool;
    pub const CommandBufferAI = c.VkCommandBufferAllocateInfo;
    pub const CommandBuffer = c.VkCommandBuffer;
    pub const Semaphore = c.VkSemaphore;
    pub const SemaphoreCI = c.VkSemaphoreCreateInfo;
    pub const Fence = c.VkFence;
    pub const FenceCI = c.VkFenceCreateInfo;
};

pub const constants = struct {
    pub const API_1_4 = c.VK_API_VERSION_1_4;
    pub const NULL_HANDLE = c.VK_NULL_HANDLE;

    // Structure Types
    pub const ST_APPLICATION_INFO = c.VK_STRUCTURE_TYPE_APPLICATION_INFO;
    pub const ST_INSTANCE_CI = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    pub const ST_DEVICE_QUEUE_CI = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    pub const ST_DEVICE_CI = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    pub const ST_SWAPCHAIN_CI = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    pub const ST_IMAGE_VIEW_CI = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    pub const ST_COMMAND_POOL_CI = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pub const ST_COMMAND_BUFFER_AI = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    pub const ST_FENCE_CI = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    pub const ST_SEMAPHORE_CI = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

    // Bool
    pub const TRUE = c.VK_TRUE;
    pub const FALSE = c.VK_FALSE;

    // VK_Results
    pub const SUCCESS = c.VK_SUCCESS;

    // Extension Names
    pub const EN_DEBUG_UTILS = c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
    pub const EN_SWAPCHAIN = c.VK_KHR_SWAPCHAIN_EXTENSION_NAME;

    // Physical Device Types
    pub const PDT_DISCRETE_GPU = c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;

    // Queue bits
    pub const B_QUEUE_GRAPHICS = c.VK_QUEUE_GRAPHICS_BIT;

    // Formats
    pub const F_B8G8R8A8_SRGB = c.VK_FORMAT_B8G8R8A8_SRGB;

    // Color Spaces
    pub const CS_SRGB_NONLINEAR = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;

    // Present Modes
    pub const PM_MAILBOX = c.VK_PRESENT_MODE_MAILBOX_KHR;

    // Image Usage bits
    pub const B_IU_COLOR_ATTACHMENT = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    // Image Aspect bits
    pub const B_IA_COLOR = c.VK_IMAGE_ASPECT_COLOR_BIT;

    // Sharing mode
    pub const SM_CONCURRENT = c.VK_SHARING_MODE_CONCURRENT;
    pub const SM_EXCLUSIVE = c.VK_SHARING_MODE_EXCLUSIVE;

    // Composite Alpha bits
    pub const B_CA_OPAQUE = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

    // Command Pool Create bits
    pub const B_CPC_RESET_COMMAND_BUFFER = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

    // Command Buffer Level
    pub const CBL_PRIMARY = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY;

    // Swizzles
    pub const COMPONENT_SWIZZLE_IDENTITY = c.VK_COMPONENT_SWIZZLE_IDENTITY;

    // Image View Types
    pub const IVT_2D = c.VK_IMAGE_VIEW_TYPE_2D;
};
