const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("blackhole", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "blackhole",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "blackhole", .module = mod },
            },
        }),
    });

    const vk_lib_name = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan";
    mod.linkSystemLibrary(vk_lib_name, .{ .needed = true });
    
    addVulkanHeaders(b, mod);

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    mod.linkLibrary(sdl_lib);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn addVulkanHeaders(b: *std.Build, mod: *std.Build.Module) void {
    const vk_sdk_path =
        b.graph.environ_map.get("VK_SDK_PATH") orelse
        b.graph.environ_map.get("VULKAN_SDK") orelse
        std.debug.panic("Error getting VK_SDK_PATH or VULKAN_SDK environment variable", .{});

    const lib_path = std.fmt.allocPrint(b.allocator, "{s}/lib", .{ vk_sdk_path }) catch @panic("OOM");
    defer b.allocator.free(lib_path);

    const include_path = std.fmt.allocPrint(b.allocator, "{s}/Include/", .{vk_sdk_path}) catch @panic("OOM");
    defer b.allocator.free(include_path);

    mod.addLibraryPath(.{ .cwd_relative = lib_path });
    mod.addIncludePath(.{ .cwd_relative = include_path });
}
