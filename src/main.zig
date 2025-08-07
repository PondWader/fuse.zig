const std = @import("std");
const fuse_zig = @import("fuse_zig");

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try fuse_zig.bufferedPrint();

    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();

    const fuse = try fuse_zig.Fuse.open(allocator);
    std.debug.print("AAAAAAAAAAa {}\n", .{fuse.fd});
    defer fuse.close();
    try fuse.start();
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
