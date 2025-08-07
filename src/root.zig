const std = @import("std");
pub const protocol = @import("./protocol.zig");

const IN_BUF_DEFAULT_SIZE = 256;

pub const Fuse = struct {
    fd: i32,
    in_buf: []u8,
    allocator: ?std.mem.Allocator,

    pub fn open(allocator: std.mem.Allocator) !@This() {
        const in_buf = try allocator.alloc(u8, IN_BUF_DEFAULT_SIZE);
        var fuse = try _open("/dev/fuse", in_buf);
        fuse.allocator = allocator;
        return fuse;
    }

    pub fn _open(dev_path: []const u8, buf: []u8) !@This() {
        const fuse: Fuse = .{
            .fd = try std.posix.open(dev_path, .{ .CLOEXEC = true, .ACCMODE = .RDWR }, 0o666),
            .in_buf = buf,
            .allocator = null,
        };
        return fuse;
    }

    /// Closes the fuse file system.
    /// If `allocator` is set, all memory used will be deallocated. Therefore, it is important that you do not use the instance after calling this method.
    pub fn close(self: @This()) void {
        std.posix.close(self.fd);
        if (self.allocator != null) {
            self.allocator.?.free(self.in_buf);
        }
    }

    /// Starts the read loop of the fuse device file handle.
    pub fn start(self: @This()) !void {
        while (true) {
            std.debug.print("{}\n", .{self.fd});
            const res = try std.posix.read(self.fd, self.in_buf);
            self.process_buf(self.in_buf[0..res]);
        }
    }

    // pub fn init(self: @This()) void {
    //     const init_in = protocol.InitIn{
    //         .major = 0,
    //         .minor = 0,
    //         .max_readahead = 0,
    //         .flags = 0,
    //     };

    //     self.write(std.mem.asBytes(@constCast(&init_in)), 0);
    // }

    /// Pass in data read from the file descriptor.
    /// This can be useful for using an event loop.
    pub fn process_buf(self: @This(), buf: []u8) void {
        _ = self;
        std.debug.print("{s}", .{buf});
    }

    fn write(self: @This(), buf: []u8, unique: u64) void {
        const header = protocol.OutHeader{
            .len = @truncate(buf.len),
            .@"error" = 0,
            .unique = unique,
        };
        _ = self.fd;
        _ = header;
    }
};

pub fn bufferedPrint() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
