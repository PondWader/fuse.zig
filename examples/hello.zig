const std = @import("std");
const fusez = @import("fusez");

var name_buf: [128]u8 = undefined;
var name_len: usize = 0;

pub fn main() !void {
    @memcpy(name_buf[0..5], "world");
    name_len = 5;

    var da = std.heap.DebugAllocator(.{}){};
    const allocator = da.allocator();
    defer _ = da.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip the executable path
    std.debug.assert(args.skip());

    const mount_path = args.next();
    if (mount_path == null) {
        std.debug.print("You must provide the path to mount at as the first argument!\n", .{});
        std.process.exit(1);
    }

    var fuse = try fusez.Fuse.mount(allocator, mount_path.?, .{}, &handlers);
    defer fuse.unmount() catch unreachable;

    std.debug.print("Mounted filesystem at {s}\n", .{mount_path.?});

    try fuse.start();
}

fn stat(ino: u64) !fusez.protocol.Attr {
    if (ino == 1) return .{ // Root directory
        .ino = ino,
        .mode = std.posix.S.IFDIR | 0o755,
        .nlink = 2,
    } else if (ino == 2) { // "hello" file
        return .{
            .ino = ino,
            .mode = std.posix.S.IFREG | 0o444,
            .nlink = 1,
            .size = name_len + 8,
        };
    } else if (ino == 3) { // "name" file
        return .{
            .ino = ino,
            .mode = std.posix.S.IFREG | 0o666,
            .nlink = 1,
            .size = name_len,
        };
    }

    return error.NoEntry;
}

const handlers = fusez.MessageHandlers{
    .getattr = .{ .handler = getattr },
    .readdir = .{ .handler = readdir },
    .lookup = .{ .handler = lookup },
    .open = .{ .handler = open },
    .read = .{ .handler = read },
    .write = .{ .handler = write },
};

fn getattr(_: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, _: *const fusez.protocol.GetattrIn) fusez.FuseResponse(fusez.protocol.AttrOut) {
    const attr = stat(header.nodeid) catch return .{
        .@"error" = .NOENT,
    };

    return .{
        .body = .{
            .attr_valid = 1,
            .attr_valid_nsec = 1e9,
            .attr = attr,
        },
    };
}

fn readdir(_: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, msg: *const fusez.protocol.ReadIn) fusez.FuseResponse(fusez.protocol.DirEntryList) {
    if (header.nodeid != 1) return .{
        .@"error" = .NOTDIR,
    };

    var dir_list: fusez.protocol.DirEntryList = .{
        .offset = msg.offset,
    };

    _ = dir_list.addEntry(.{
        .ino = 1,
        .name_len = 1,
        .type = 0,
        .offset = 1,
    }, ".");
    _ = dir_list.addEntry(.{
        .ino = 1,
        .name_len = 2,
        .type = 0,
        .offset = 2,
    }, "..");
    _ = dir_list.addEntry(.{
        .ino = 2,
        .name_len = 5,
        .type = 0,
        .offset = 3,
    }, "hello");
    _ = dir_list.addEntry(.{
        .ino = 3,
        .name_len = 4,
        .type = 0,
        .offset = 4,
    }, "name");

    return .{
        .body = dir_list,
    };
}

fn lookup(_: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, msg: *const fusez.protocol.LookupIn) fusez.FuseResponse(fusez.protocol.EntryOut) {
    if (header.nodeid != 1) {
        return .{
            .@"error" = .NOENT,
        };
    }

    var ino: u64 = undefined;
    if (std.mem.eql(u8, msg.name, "hello")) {
        ino = 2;
    } else if (std.mem.eql(u8, msg.name, "name")) {
        ino = 3;
    } else return .{
        .@"error" = .NOENT,
    };

    const attr = stat(ino) catch return .{
        .@"error" = .NOENT,
    };

    return .{
        .body = .{
            .nodeid = ino,
            .attr_valid = 1,
            .attr_valid_nsec = 1e9,
            .entry_valid = 1,
            .entry_valid_nsec = 1e9,
            .attr = attr,
        },
    };
}

fn open(_: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, _: *const fusez.protocol.OpenIn) fusez.FuseResponse(fusez.protocol.OpenOut) {
    if (header.nodeid == 1) {
        return .{
            .@"error" = .ISDIR,
        };
    } else if (header.nodeid != 2 and header.nodeid != 3) {
        return .{
            .@"error" = .NOENT,
        };
    }

    // TODO: check it's RDONLY for "hello"

    return .{
        .body = .{
            .fh = 1,
            .open_flags = 0,
        },
    };
}

fn read(fuse: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, _: *const fusez.protocol.ReadIn) fusez.FuseResponse([]const u8) {
    if (header.nodeid == 2) { // "hello"
        var out_buf: [256]u8 = undefined;
        @memcpy(out_buf[0..6], "Hello ");
        @memcpy(out_buf[6 .. 6 + name_len], name_buf[0..name_len]);
        @memcpy(out_buf[6 + name_len .. 8 + name_len], "!\n");

        return .{
            .result = fuse.write_response(.SUCCESS, header.unique, out_buf[0 .. 8 + name_len]),
        };
    } else if (header.nodeid == 3) { // "name"
        return .{
            .body = name_buf[0..name_len],
        };
    } else {
        return .{
            .@"error" = .NOENT,
        };
    }
}

fn write(_: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, req: *const fusez.WriteRequest) fusez.FuseResponse(fusez.protocol.WriteOut) {
    if (header.nodeid != 3) return .{ .@"error" = .ROFS };
    // Don't support offsets since it doesn't work well with trimming
    if (req.msg.offset != 0) return .{ .@"error" = .INVAL };

    var new_name = req.payload[0..req.msg.size];
    new_name = std.mem.trim(u8, new_name, &.{ ' ', '\t', '\n' });

    // Truncate the name if necessary
    if (new_name.len > name_buf.len) {
        new_name = new_name[0..name_buf.len];
    }

    @memcpy(name_buf[0..new_name.len], new_name);
    name_len = new_name.len;

    return .{
        .body = .{
            .size = req.msg.size,
        },
    };
}
