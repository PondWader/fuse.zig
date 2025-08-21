const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("fusez", .{
        .root_source_file = b.path("src/fuse.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "fusez",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "fusez", .module = mod },
            },
        }),
    });

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

    const check = b.step("check", "Check if the project compiles");
    check.dependOn(&exe.step);

    // Add examples
    const example_executables = try buildExamples(b, target, optimize);

    for (example_executables) |example_exe| {
        // Create individual run step for each example
        const example_name = example_exe.name;
        const example_run_step = b.step(b.fmt("example-{s}", .{example_name}), b.fmt("Run the {s} example", .{example_name}));

        const example_run_cmd = b.addRunArtifact(example_exe);
        example_run_step.dependOn(&example_run_cmd.step);
        example_run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            example_run_cmd.addArgs(args);
        }
    }
}

fn buildExamples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) ![]const *std.Build.Step.Compile {
    var steps = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);
    defer steps.deinit();

    var dir = try std.fs.cwd().openDir(try b.build_root.join(
        b.allocator,
        &.{"examples"},
    ), .{ .iterate = true });
    defer dir.close();

    // Go through and add each as a step
    var it = dir.iterate();
    while (try it.next()) |entry| {
        // Get the index of the last '.' so we can strip the extension.
        const index = std.mem.lastIndexOfScalar(
            u8,
            entry.name,
            '.',
        ) orelse continue;
        if (index == 0) continue;

        // Name of the app and full path to the entrypoint.
        const name = entry.name[0..index];

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt(
                    "examples/{s}",
                    .{entry.name},
                )),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("fusez", b.modules.get("fusez").?);

        // Store the mapping
        try steps.append(exe);
    }

    return try steps.toOwnedSlice();
}
