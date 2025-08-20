const std = @import("std");
const fusez = @import("fusez");

pub fn main() !void {
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

const handlers = fusez.MessageHandlers{
    .getattr = .{ .handler = getattr },
    .readdir = .{ .handler = readdir },
    .lookup = .{ .handler = lookup },
};

fn getattr(_: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, _: *const fusez.protocol.GetattrIn) fusez.FuseResponse(fusez.protocol.AttrOut) {
    if (header.nodeid == 1) {
        return .{
            .body = .{
                .attr_valid = 1,
                .attr_valid_nsec = 1e9,
                .attr = .{
                    .ino = 1,
                    .mode = std.posix.S.IFDIR | 0o755,
                    .nlink = 2,
                },
            },
        };
    }

    return .{
        .@"error" = .NOENT,
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

    return .{
        // TODO: Don't be returning value abt to be popped off stack, fuse should have a buffer pool
        .body = dir_list,
    };
}

fn lookup(_: *fusez.Fuse, header: *const fusez.protocol.HeaderIn, msg: *const fusez.protocol.LookupIn) fusez.FuseResponse(fusez.protocol.EntryOut) {
    if (header.nodeid != 1 or !std.mem.eql(u8, msg.name, "hello")) {
        return .{
            .@"error" = .NOENT,
        };
    }

    return .{
        .body = .{
            .nodeid = 2,
            .attr_valid = 1,
            .attr_valid_nsec = 1e9,
            .entry_valid = 1,
            .entry_valid_nsec = 1e9,
            .attr = .{
                .ino = 2,
                .mode = std.posix.S.IFREG | 0o444,
                .nlink = 1,
                .size = 9,
            },
            .generation = 1,
        },
    };
}
