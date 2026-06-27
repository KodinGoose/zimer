const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zimer_mod = b.createModule(.{
        .root_source_file = b.path("src/timer.zig"),
        .target = target,
        .optimize = optimize,

        .error_tracing = if (optimize == .Debug) true else false,
        .link_libc = false,
        .link_libcpp = false,
        .omit_frame_pointer = if (optimize == .Debug) false else true,
        .red_zone = if (optimize == .Debug) true else false,
        .sanitize_c = if (optimize == .Debug) .full else .off,
        .sanitize_thread = false,
        .single_threaded = true,
        .strip = if (optimize == .Debug) false else true,
        .stack_check = if (optimize == .Debug) true else false,
        .stack_protector = if (optimize == .Debug) null else false,
        .unwind_tables = if (optimize == .Debug) .sync else .none,
        .valgrind = if (optimize == .Debug) true else false,

        // No need for this since I'm not doing any fuzz testing on this project
        .fuzz = false,

        // This only has an effect on debug builds and is ignored on release builds.
        // Since this project doesn't and never will exceed 4GB in binary size I decided
        // to leave this up to the compiler.
        .dwarf_format = null,

        // I presume that this is about llvm built-in functions and not zig "@" functions
        // since "@" functions can still be used with this being true.
        // Even so I'd rather leave this up to the zig compiler since I'm not entirely sure.
        // Information on this option is rather hard to come by.
        .no_builtin = null,

        .imports = &.{
            // .{ .name = "shared", .module = shared_mod },
        },
    });
    const zimer_exe = b.addExecutable(.{
        .name = "zimer",
        .root_module = zimer_mod,
    });

    b.installArtifact(zimer_exe);
}
