const std = @import("std");
const fusez = @import("fusez");

pub fn main() !void {
    std.debug.print("Starting...\n", .{});

    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();

    // try fusermount3.fusermount3(allocator, "/mnt/test");

    var fuse = try fusez.Fuse.mount(allocator, "/mnt/test", .{
        .allow_other = false,
        .fs_name = "my_test_fs",
        .subtype = "fuse_test",
    }, &.{});
    defer fuse.unmount() catch unreachable;
    try fuse.start();
}
