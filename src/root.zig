const std = @import("std");
pub const protocol = @import("./protocol.zig");
const fusermount3 = @import("./fusermount3.zig").fusermount3;
const SliceJoiner = @import("./util/slice_joiner.zig").SliceJoiner;

pub const MountOptions = struct {
    allow_other: bool = false,
    fs_name: ?[]const u8 = null,
    subtype: ?[]const u8 = null,

    /// Creates a string for passing to fusermount3 in the `-o` flag. The caller should free returned memory.
    pub fn createOptionsString(self: MountOptions, allocator: std.mem.Allocator) ![]const u8 {
        // Important: When adding more append calls be sure to increase the capacity of the SliceJoiner.
        var joiner = SliceJoiner(u8, 5, ","){};

        if (self.allow_other) {
            joiner.append("allow_other");
        }

        var fs_name = self.fs_name;
        var subtype = self.subtype;

        defer {
            // If the values have changed (a replacement has occured), they should be deallocated.
            if (self.fs_name != null and self.fs_name.?.ptr != fs_name.?.ptr) {
                allocator.free(fs_name.?);
            }
            if (self.subtype != null and self.subtype.?.ptr != subtype.?.ptr) {
                allocator.free(subtype.?);
            }
        }

        if (fs_name) |name| {
            joiner.append("fsname=");
            fs_name = try escapeOption(allocator, name);
            joiner.append(name);
        }
        if (subtype) |st| {
            joiner.append("subtype=");
            subtype = try escapeOption(allocator, st);
            joiner.append(st);
        }

        return joiner.result(allocator);
    }

    /// Escapes values for the options string. "," is replaced with "\," and "\" with "\\".
    /// This function will only allocate if the value needs replaced and so the returned value should only be freed
    /// if it does not equal the `value` argument.
    fn escapeOption(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
        var new_size: usize = value.len;
        for (value) |c| {
            if (c == ',' or c == '\\') {
                new_size += 1;
            }
        }

        // If the new size isn't any larger, there are no replacements to be made.
        if (new_size == value.len) {
            return value;
        }

        const new_value = try allocator.alloc(u8, new_size);
        var i: usize = 0;
        for (value) |c| {
            if (c == ',' or c == '\\') {
                new_value[i] = '\\';
                i += 1;
            }
            new_value[i] = c;
            i += 1;
        }
        return new_value;
    }
};

/// This is the minimum size that any buffers reading from the fuse file handle should be.
pub const MIN_READ_BUFFER_SIZE = 8192;

/// A handler for a fuse filesystem connection.
pub const Fuse = struct {
    fd: i32,
    allocator: ?std.mem.Allocator = null,

    /// Mounts a new fuse filesystem at the given mount point.
    pub fn mount(allocator: std.mem.Allocator, mountPoint: []const u8, options: MountOptions) !@This() {
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        const arena = arena_allocator.allocator();
        defer arena_allocator.deinit();

        const fd = try fusermount3(arena, mountPoint, options);

        const fuse = Fuse{
            .fd = fd,
            .allocator = allocator,
        };

        return fuse;
    }

    /// Closes the fuse file system.
    /// If `allocator` is set, all memory used will be deallocated. Therefore, it is important that you do not use the instance after calling this method.
    pub fn close(self: @This()) void {
        std.posix.close(self.fd);
    }

    /// Starts the read loop of the fuse device file handle.
    /// The `allocator` property must not be null so a read buffer can be allocated. Otherwise, you should call `startWithBuf` and pass your own buffer.
    pub fn start(self: @This()) !void {
        std.debug.assert(self.allocator != null);

        const buf = try self.allocator.?.alignedAlloc(u8, .@"64", MIN_READ_BUFFER_SIZE);
        defer self.allocator.?.free(buf);

        return self.startWithBuf(buf);
    }

    /// Starts the read loop of the fuse device file handle.
    /// This function takes a buffer for reading which should be at least `MIN_READ_BUFFER_SIZE` in size.
    pub fn startWithBuf(self: @This(), buf: []u8) !void {
        while (true) {
            const res = try std.posix.read(self.fd, buf);
            self.handle_buf(buf[0..res]);
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

    /// Used to handle data read from the file descriptor.
    /// You should use this if you wish to implement your own reader/event loop for reading from the fuse file handle. The `buf` slice should be the size of the data read.
    pub fn handle_buf(self: @This(), buf: []u8) void {
        _ = self;
        std.debug.assert(buf.len >= @sizeOf(protocol.InHeader));

        const header: *align(1) protocol.InHeader = std.mem.bytesAsValue(protocol.InHeader, buf);

        std.debug.assert(header.len == buf.len);

        std.debug.print("{}\n", .{header});
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

/// Aligns
fn alignBuf(buf: []u8, aligned_byte: usize, block_size: usize, size: usize) []u8 {
    const buf_ptr = @intFromPtr(buf.ptr);
    const aligned_ptr = buf_ptr + aligned_byte;
    const misaligned = aligned_ptr & (block_size - 1);
    const offset = block_size - misaligned;
    return buf[offset..][0..size];
}

fn directMount() !void {
    try std.posix.open("/dev/fuse", .{ .CLOEXEC = true, .ACCMODE = .RDWR }, 0);
}
