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
    defer fuse.close();
    try fuse.start();
    std.time.sleep(std.time.ns_per_hour);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
