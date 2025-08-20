const std = @import("std");
pub const protocol = @import("./protocol.zig");
const fusermount3 = @import("./fusermount3.zig");
const SliceJoiner = @import("./util/slice_joiner.zig").SliceJoiner;

/// This is the minimum size that any buffers reading from the fuse file handle should be.
pub const MIN_READ_BUFFER_SIZE = 8192;
const FUSE_KERNEL_VERSION = 7;
const FUSE_DAEMON_MINOR_VERSION = 44;
const FUSE_KERNEL_MIN_MINOR_VERSION = 12;

pub const WriteError = std.posix.WriteError;

pub fn FuseResponse(comptime T: type) type {
    return union(enum) {
        @"error": std.posix.E,
        body: T,
        result: WriteError!void,

        inline fn write(self: @This(), fuse: *Fuse, unique: u64) !void {
            switch (self) {
                .@"error" => |*errno| try fuse.write_response(errno.*, unique, &.{}),
                .body => |*b| {
                    if (T == void) {
                        try fuse.write_response(.SUCCESS, unique, &.{});
                    } else if (std.meta.hasMethod(T, "toBuf")) {
                        try fuse.write_response(.SUCCESS, unique, b.*.toBuf());
                    } else if (T == []u8 or T == []const u8) {
                        try fuse.write_response(.SUCCESS, unique, b.*);
                    } else {
                        try fuse.write_response(.SUCCESS, unique, std.mem.asBytes(b));
                    }
                },
                .result => |*e| {
                    return e.*;
                },
            }
        }
    };
}

pub fn FuseHandler(comptime Request: type, comptime Response: type) type {
    comptime var handler: type = fn (fuse: *Fuse, header: *const protocol.HeaderIn) FuseResponse(Response);
    if (Request != void) {
        handler = fn (fuse: *Fuse, header: *const protocol.HeaderIn, msg: *const Request) FuseResponse(Response);
    }

    return struct {
        handler: ?*const handler = null,

        inline fn use(self: @This(), fuse: *Fuse, header: *const protocol.HeaderIn) !void {
            if (self.handler) |handler_fn| {
                try handler_fn(fuse, header).write(fuse, header.unique);
            } else {
                const res = FuseResponse(void){
                    .@"error" = .NOSYS,
                };
                try res.write(fuse, header.unique);
            }
        }

        inline fn use_with_body(self: @This(), fuse: *Fuse, header: *const protocol.HeaderIn, body: []u8) !void {
            if (self.handler) |handler_fn| {
                if (std.meta.hasFn(Request, "fromBuf")) {
                    try handler_fn(fuse, header, &Request.fromBuf(body)).write(fuse, header.unique);
                } else {
                    try handler_fn(fuse, header, @alignCast(@ptrCast(body))).write(fuse, header.unique);
                }
            } else {
                const res = FuseResponse(void){
                    .@"error" = .NOSYS,
                };
                try res.write(fuse, header.unique);
            }
        }
    };
}

/// Struct used to define the handlers for different message types.
/// Please note, pointers should be dereferenced if the value is going to be used after returning as the previous data will be overwritten.
pub const MessageHandlers = struct {
    lookup: FuseHandler(protocol.LookupIn, protocol.EntryOut) = .{},
    forget: FuseHandler(void, void) = .{},
    getattr: FuseHandler(protocol.GetattrIn, protocol.AttrOut) = .{},
    setattr: FuseHandler(void, protocol.AttrOut) = .{},
    readlink: FuseHandler(void, void) = .{},
    symlink: FuseHandler(void, protocol.EntryOut) = .{},
    mknod: FuseHandler(void, protocol.EntryOut) = .{},
    mkdir: FuseHandler(void, protocol.EntryOut) = .{},
    unlink: FuseHandler(void, void) = .{},
    rmdir: FuseHandler(void, void) = .{},
    rename: FuseHandler(void, void) = .{},
    link: FuseHandler(void, protocol.EntryOut) = .{},
    open: FuseHandler(protocol.OpenIn, protocol.OpenOut) = .{},
    read: FuseHandler(protocol.ReadIn, []const u8) = .{},
    write: FuseHandler(protocol.WriteIn, protocol.WriteOut) = .{},
    statfs: FuseHandler(void, protocol.StatfsOut) = .{},
    release: FuseHandler(protocol.ReleaseIn, void) = .{},
    fsync: FuseHandler(void, void) = .{},
    setxattr: FuseHandler(void, void) = .{},
    getxattr: FuseHandler(void, void) = .{},
    listxattr: FuseHandler(void, void) = .{},
    removexattr: FuseHandler(void, void) = .{},
    flush: FuseHandler(protocol.FlushIn, void) = .{},
    /// init has a default handler which you may override. This handler will apply certain MountOptions so if you override it, be aware the behaviour may change.
    init: FuseHandler(protocol.InitIn, protocol.InitOut) = .{ .handler = init_handler },
    opendir: FuseHandler(protocol.OpenIn, protocol.OpenOut) = .{},
    readdir: FuseHandler(protocol.ReadIn, protocol.DirEntryList) = .{},
    releasedir: FuseHandler(protocol.ReleaseIn, void) = .{},
    fsyncdir: FuseHandler(void, void) = .{},
    getlk: FuseHandler(void, void) = .{},
    setlk: FuseHandler(void, void) = .{},
    setlkw: FuseHandler(void, void) = .{},
    access: FuseHandler(protocol.AccessIn, void) = .{},
    create: FuseHandler(protocol.OpenIn, protocol.OpenOut) = .{},
    interrupt: FuseHandler(protocol.InterruptIn, void) = .{},
    bmap: FuseHandler(void, void) = .{},
    destroy: FuseHandler(void, void) = .{},
    ioctl: FuseHandler(void, void) = .{},
    poll: FuseHandler(void, void) = .{},
    notify_reply: FuseHandler(void, void) = .{},
    batch_forget: FuseHandler(void, void) = .{},
    fallocate: FuseHandler(void, void) = .{},
    readdirplus: FuseHandler(protocol.ReadIn, void) = .{},
    rename2: FuseHandler(void, void) = .{},
    lseek: FuseHandler(void, void) = .{},
    copy_file_range: FuseHandler(void, void) = .{},

    fn init_handler(fuse: *Fuse, _: *const protocol.HeaderIn, msg: *const protocol.InitIn) FuseResponse(protocol.InitOut) {
        if (msg.major != FUSE_KERNEL_VERSION or msg.minor < FUSE_KERNEL_MIN_MINOR_VERSION) {
            return .{
                .@"error" = .IO,
            };
        }

        fuse.kernel_flags = msg.get_flags();

        var out_flags: protocol.CapFlags = fuse.kernel_flags.?.merge(fuse.options.flags);
        out_flags.INIT_EXT = true;

        const max_pages: u16 = @truncate((fuse.options.max_write - 1) / @as(u32, std.heap.pageSize()) + 1);

        var out: protocol.InitOut = .{
            .major = FUSE_KERNEL_VERSION,
            .minor = FUSE_DAEMON_MINOR_VERSION,
            .max_readahead = msg.max_readahead,
            .max_write = fuse.options.max_write,
            .max_background = fuse.options.max_background,
            .congestion_threshold = fuse.options.congestion_threshold,
            .max_pages = max_pages,
            .max_stack_depth = 0,
            .flags = @truncate(@as(u64, @bitCast(out_flags))),
            .flags2 = @truncate(@as(u64, @bitCast(out_flags)) >> 32),
            .time_gran = 1000000000,
            .map_alignment = 0,
            .request_timeout = 0,
        };

        if (out.minor > msg.minor) {
            out.minor = msg.minor;
        }

        return .{
            .body = out,
        };
    }
};

pub const BackingStackDepth = enum(u32) {
    /// Backing files cannot be on a stacked filesystem, but another stacked
    /// filesystem can be stacked over this FUSE passthrough filesystem.
    STACKED_UNDER = 0,
    /// Backing files may be on a stacked filesystem, such as overlayfs or
    /// another FUSE passthrough. In this configuration, another stacked
    /// filesystem cannot be stacked over this FUSE passthrough filesystem.
    STACKED_OVER = 1,
    _,
};

pub const MountOptions = struct {
    /// Allows other users to access the filesystem. If enabling this, you should probably enable `default_permissions` due to https://github.com/libfuse/libfuse/issues/15.
    allow_other: bool = false,
    /// This option instructs the kernel to perform its own permission check
    /// instead of deferring all permission checking to the
    /// filesystem. The check by the kernel is done in addition to any
    /// permission checks by the filesystem, and both have to succeed for an
    /// operation to be allowed. The kernel performs a standard UNIX permission
    /// check (based on mode bits and ownership of the directory entry, and
    /// uid/gid of the client).
    default_permissions: bool = false,
    fs_name: ?[]const u8 = null,
    subtype: ?[]const u8 = null,
    flags: protocol.CapFlags = .{},
    /// Controls the maximum size for write requests.
    /// This value defaults to 256 KiB. A value greater than the kernel max write doesn't make sense (generally 1 MiB).
    max_write: u32 = 256 * 1024,
    /// Controls the maximum size for read requests.
    /// A value of 0, the default, corresponds to infinite.
    max_read: u32 = 0,
    /// Defines the maximum number of pending background requests (read-ahead requests and async direct I/O requests).
    ///
    /// Read-ahead requests are generated (if max_readahead is
    /// non-zero) by the kernel to preemptively fill its caches
    /// when it anticipates that userspace will soon read more
    /// data.
    ///
    /// Asynchronous direct I/O requests are generated if
    /// FUSE_CAP_ASYNC_DIO is enabled and userspace submits a large
    /// direct I/O request. In this case the kernel will internally
    /// split it up into multiple smaller requests and submit them
    /// to the filesystem concurrently.
    max_background: u16 = 12,
    /// Kernel congestion threshold parameter. If the number of pending
    /// background requests exceeds this number (see `MountOptions.max_background`), the FUSE kernel module will
    /// mark the filesystem as "congested". This instructs the kernel to
    /// expect that queued requests will take some time to complete, and to
    /// adjust its algorithms accordingly (e.g. by putting a waiting thread
    /// to sleep instead of using a busy-loop).
    congestion_threshold: u16 = 8,
    /// When the PASSTHROUGH capability is enabled, this defines the maximum allowed
    /// stacking depth of the backing files. The default is STACKED_UNDER,
    /// meaning backing files cannot be on a stacked filesystem, but another
    /// stacked filesystem can be stacked over this FUSE passthrough filesystem.
    max_backing_stack_depth: BackingStackDepth = .STACKED_UNDER,

    /// Creates a string for passing to fusermount3 in the `-o` flag. The caller should free returned memory.
    pub fn createOptionsString(self: MountOptions, allocator: std.mem.Allocator) ![]const u8 {
        // Important: When adding more append calls be sure to increase the capacity of the SliceJoiner.
        var joiner = SliceJoiner(u8, 9){};

        if (self.allow_other) {
            joiner.append("allow_other,");
        }
        if (self.default_permissions) {
            joiner.append("default_permissions,");
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
            joiner.append(",");
        }
        if (subtype) |st| {
            joiner.append("subtype=");
            subtype = try escapeOption(allocator, st);
            joiner.append(st);
            joiner.append(",");
        }

        // Use a stack buffer to format the max_read=<size> option
        var buf: [19]u8 = undefined;
        @memcpy(buf[0..9], "max_read=");
        const size = std.fmt.formatIntBuf(buf[9..], self.max_read, 10, .lower, .{});
        joiner.append(buf[0 .. 9 + size]);

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

/// A handler for a fuse filesystem connection.
pub const Fuse = struct {
    fd: i32,
    handlers: *const MessageHandlers,
    options: MountOptions,
    mount_point: []const u8,
    allocator: ?std.mem.Allocator = null,
    kernel_flags: ?protocol.CapFlags = null,

    /// Mounts a new fuse filesystem at the given mount point.
    pub fn mount(allocator: std.mem.Allocator, mount_point: []const u8, options: MountOptions, handlers: *const MessageHandlers) !@This() {
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        const arena = arena_allocator.allocator();
        defer arena_allocator.deinit();

        var mount_options = options;
        // Default to 3/4 of max_background as the congest_threshold if it's invalid.
        if (mount_options.congestion_threshold > mount_options.congestion_threshold) {
            mount_options.congestion_threshold = mount_options.max_background * 3 / 4;
        }

        const fd = try fusermount3.mount(arena, mount_point, options);

        const fuse = Fuse{
            .fd = fd,
            .handlers = handlers,
            .options = mount_options,
            .mount_point = mount_point,
            .allocator = allocator,
        };

        return fuse;
    }

    /// Closes the fuse file system. The `allocator` property (automatically set by calling `mount`) must not be null.
    pub fn unmount(self: *@This()) !void {
        std.posix.close(self.fd);

        const mount_point = std.posix.toPosixPath(self.mount_point) catch unreachable;

        var arena_allocator = std.heap.ArenaAllocator.init(self.allocator.?);
        const arena = arena_allocator.allocator();
        defer arena_allocator.deinit();

        try fusermount3.unmount(arena, &mount_point);
    }

    /// Starts the read loop of the fuse device file handle.
    /// The `allocator` property (automatically set by calling `mount`) must not be null so a read buffer can be allocated. Otherwise, you should call `startWithBuf` and pass your own buffer.
    pub fn start(self: *@This()) !void {
        // The read buffer must be at least MIN_READ_BUFFER_SIZE or the size of max write + HeaderIn + WriteIn, which is greater.
        const buf_size = @max(MIN_READ_BUFFER_SIZE, self.options.max_write + @sizeOf(protocol.HeaderIn) + @sizeOf(protocol.WriteIn));

        const buf = try self.allocator.?.alignedAlloc(u8, .@"64", buf_size);
        defer self.allocator.?.free(buf);

        return self.startWithBuf(buf);
    }

    /// Starts the read loop of the fuse device file handle.
    /// This function takes a buffer for reading which should be at least `MIN_READ_BUFFER_SIZE` in size.
    pub fn startWithBuf(self: *@This(), buf: []u8) !void {
        while (true) {
            const res = try std.posix.read(self.fd, buf);
            try self.handle_buf(buf[0..res]);
        }
    }

    /// Used to handle data read from the file descriptor.
    /// You should use this if you wish to implement your own reader/event loop for reading from the fuse file handle. The `buf` slice should be the size of the data read.
    pub fn handle_buf(self: *@This(), buf: []u8) !void {
        std.debug.assert(buf.len >= @sizeOf(protocol.HeaderIn));

        const header: *protocol.HeaderIn = @alignCast(std.mem.bytesAsValue(protocol.HeaderIn, buf));

        std.debug.assert(header.len == buf.len);

        const opcode: protocol.Opcode = @enumFromInt(header.opcode);
        const msg_start = @sizeOf(protocol.HeaderIn);
        const body = buf[msg_start..header.len];

        try switch (opcode) {
            .LOOKUP => self.handlers.lookup.use_with_body(self, header, body),
            .FORGET => self.handlers.forget.use(self, header),
            .GETATTR => self.handlers.getattr.use_with_body(self, header, body),
            .SETATTR => self.handlers.setattr.use(self, header),
            .READLINK => self.handlers.readlink.use(self, header),
            .SYMLINK => self.handlers.symlink.use(self, header),
            .MKNOD => self.handlers.mknod.use(self, header),
            .MKDIR => self.handlers.mkdir.use(self, header),
            .UNLINK => self.handlers.unlink.use(self, header),
            .RMDIR => self.handlers.rmdir.use(self, header),
            .RENAME => self.handlers.rename.use(self, header),
            .LINK => self.handlers.link.use(self, header),
            .OPEN => self.handlers.open.use_with_body(self, header, body),
            .READ => self.handlers.read.use_with_body(self, header, body),
            .WRITE => self.handlers.write.use_with_body(self, header, body),
            .STATFS => self.handlers.statfs.use(self, header),
            .RELEASE => self.handlers.release.use_with_body(self, header, body),
            .FSYNC => self.handlers.fsync.use(self, header),
            .SETXATTR => self.handlers.setxattr.use(self, header),
            .GETXATTR => self.handlers.getxattr.use(self, header),
            .LISTXATTR => self.handlers.listxattr.use(self, header),
            .REMOVEXATTR => self.handlers.removexattr.use(self, header),
            .FLUSH => self.handlers.flush.use_with_body(self, header, body),
            .INIT => self.handlers.init.use_with_body(self, header, body),
            .OPENDIR => self.handlers.opendir.use_with_body(self, header, body),
            .READDIR => self.handlers.readdir.use_with_body(self, header, body),
            .RELEASEDIR => self.handlers.releasedir.use_with_body(self, header, body),
            .FSYNCDIR => self.handlers.fsyncdir.use(self, header),
            .GETLK => self.handlers.getlk.use(self, header),
            .SETLK => self.handlers.setlk.use(self, header),
            .SETLKW => self.handlers.setlkw.use(self, header),
            .ACCESS => self.handlers.access.use_with_body(self, header, body),
            .CREATE => self.handlers.create.use_with_body(self, header, body),
            .INTERRUPT => self.handlers.interrupt.use_with_body(self, header, body),
            .BMAP => self.handlers.bmap.use(self, header),
            .DESTROY => self.handlers.destroy.use(self, header),
            .IOCTL => self.handlers.ioctl.use(self, header),
            .POLL => self.handlers.poll.use(self, header),
            .NOTIFY_REPLY => self.handlers.notify_reply.use(self, header),
            .BATCH_FORGET => self.handlers.batch_forget.use(self, header),
            .FALLOCATE => self.handlers.fallocate.use(self, header),
            .READDIRPLUS => self.handlers.readdirplus.use_with_body(self, header, body),
            .RENAME2 => self.handlers.rename2.use(self, header),
            .LSEEK => self.handlers.lseek.use(self, header),
            .COPY_FILE_RANGE => self.handlers.copy_file_range.use(self, header),
            else => {
                const res = FuseResponse(void){
                    .@"error" = .NOSYS,
                };
                try res.write(self, header.unique);
            },
        };
    }

    pub fn write_response(self: *@This(), err: std.posix.E, unique: u64, data: []const u8) WriteError!void {
        const errno = @as(i32, @intFromEnum(err));

        var header = protocol.HeaderOut{
            .len = @truncate(data.len + @sizeOf(protocol.HeaderOut)),
            .@"error" = -errno,
            .unique = unique,
        };

        if (errno != 0 or data.len == 0) {
            header.len -= @intCast(data.len);
            _ = try std.posix.write(self.fd, std.mem.asBytes(&header));
            return;
        }

        const iov = [_]std.posix.iovec_const{
            std.posix.iovec_const{
                .base = @constCast(std.mem.asBytes(&header)).ptr,
                .len = @sizeOf(protocol.HeaderOut),
            },
            std.posix.iovec_const{
                .base = @constCast(data.ptr),
                .len = data.len,
            },
        };

        _ = try std.posix.writev(self.fd, &iov);
    }
};

fn directMount() !void {
    try std.posix.open("/dev/fuse", .{ .CLOEXEC = true, .ACCMODE = .RDWR }, 0);
}
