const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigraylib",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const raylib_optimize = b.option(
        std.builtin.OptimizeMode,
        "raylib-optimize",
        "Prioritize performance, safety, or binary size (-O flag), defaults to value of optimize option",
    ) orelse optimize;

    const strip = b.option(
        bool,
        "strip",
        "Strip debug info to reduce binary size, defaults to false",
    ) orelse false;
    exe.root_module.strip = strip;

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = raylib_optimize,
    });
    exe.linkLibrary(raylib_dep.artifact("raylib"));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

// const std = @import("std");
// const builtin = @import("builtin");
//
// // This has been tested to work with zig 0.12.0
// fn add_module(comptime module: []const u8, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step {
//     if (target.result.os.tag == .emscripten) {
//         @panic("Emscripten building via Zig unsupported");
//     }
//
//     const all = b.step(module, "All " ++ module ++ " examples");
//     var dir = try std.fs.cwd().openDir(module, .{ .iterate = true });
//     defer if (comptime builtin.zig_version.minor >= 12) dir.close();
//
//     var iter = dir.iterate();
//     while (try iter.next()) |entry| {
//         if (entry.kind != .file) continue;
//         const extension_idx = std.mem.lastIndexOf(u8, entry.name, ".c") orelse continue;
//         const name = entry.name[0..extension_idx];
//         const path = try std.fs.path.join(b.allocator, &.{ module, entry.name });
//
//         // zig's mingw headers do not include pthread.h
//         if (std.mem.eql(u8, "core_loading_thread", name) and target.result.os.tag == .windows) continue;
//
//         const exe = b.addExecutable(.{
//             .name = name,
//             .target = target,
//             .optimize = optimize,
//         });
//         exe.addCSourceFile(.{ .file = b.path(path), .flags = &.{} });
//         exe.linkLibC();
//         exe.addObjectFile(switch (target.result.os.tag) {
//             .windows => b.path("../zig-out/lib/raylib.lib"),
//             .linux => b.path("../zig-out/lib/libraylib.a"),
//             .macos => b.path("../zig-out/lib/libraylib.a"),
//             .emscripten => b.path("../zig-out/lib/libraylib.a"),
//             else => @panic("Unsupported OS"),
//         });
//
//         exe.addIncludePath(b.path("../src"));
//         exe.addIncludePath(b.path("../src/external"));
//         exe.addIncludePath(b.path("../src/external/glfw/include"));
//
//         switch (target.result.os.tag) {
//             .windows => {
//                 exe.linkSystemLibrary("winmm");
//                 exe.linkSystemLibrary("gdi32");
//                 exe.linkSystemLibrary("opengl32");
//
//                 exe.defineCMacro("PLATFORM_DESKTOP", null);
//             },
//             .linux => {
//                 exe.linkSystemLibrary("GL");
//                 exe.linkSystemLibrary("rt");
//                 exe.linkSystemLibrary("dl");
//                 exe.linkSystemLibrary("m");
//                 exe.linkSystemLibrary("X11");
//
//                 exe.defineCMacro("PLATFORM_DESKTOP", null);
//             },
//             .macos => {
//                 exe.linkFramework("Foundation");
//                 exe.linkFramework("Cocoa");
//                 exe.linkFramework("OpenGL");
//                 exe.linkFramework("CoreAudio");
//                 exe.linkFramework("CoreVideo");
//                 exe.linkFramework("IOKit");
//
//                 exe.defineCMacro("PLATFORM_DESKTOP", null);
//             },
//             else => {
//                 @panic("Unsupported OS");
//             },
//         }
//
//         const install_cmd = b.addInstallArtifact(exe, .{});
//
//         const run_cmd = b.addRunArtifact(exe);
//         run_cmd.step.dependOn(&install_cmd.step);
//
//         const run_step = b.step(name, name);
//         run_step.dependOn(&run_cmd.step);
//
//         all.dependOn(&install_cmd.step);
//     }
//     return all;
// }
//
// pub fn build(b: *std.Build) !void {
//     // Standard target options allows the person running `zig build` to choose
//     // what target to build for. Here we do not override the defaults, which
//     // means any target is allowed, and the default is native. Other options
//     // for restricting supported target set are available.
//     const target = b.standardTargetOptions(.{});
//     // Standard optimization options allow the person running `zig build` to select
//     // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
//     // set a preferred release mode, allowing the user to decide how to optimize.
//     const optimize = b.standardOptimizeOption(.{});
//
//     const all = b.getInstallStep();
//
//     all.dependOn(try add_module("audio", b, target, optimize));
//     all.dependOn(try add_module("core", b, target, optimize));
//     all.dependOn(try add_module("models", b, target, optimize));
//     all.dependOn(try add_module("others", b, target, optimize));
//     all.dependOn(try add_module("shaders", b, target, optimize));
//     all.dependOn(try add_module("shapes", b, target, optimize));
//     all.dependOn(try add_module("text", b, target, optimize));
//     all.dependOn(try add_module("textures", b, target, optimize));
// }
