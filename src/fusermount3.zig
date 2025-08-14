const std = @import("std");
const posix = std.posix;
const fusez = @import("./root.zig");

pub fn fusermount3(arena: std.mem.Allocator, mountPoint: []const u8, options: fusez.MountOptions) !posix.fd_t {
    // Open unix socket for receiving fuse file handle
    var fd: [2]posix.fd_t = undefined;
    const socketpair_res = std.os.linux.socketpair(std.posix.AF.UNIX, std.posix.SOCK.SEQPACKET, 0, &fd);
    if (socketpair_res != 0) {
        return error.FailedToOpenSocketPair;
    }
    defer posix.close(fd[0]);
    defer posix.close(fd[1]);

    // Set _FUSE_COMMFD to the third file
    var env_map = std.process.EnvMap.init(arena);
    try env_map.put("_FUSE_COMMFD", "3");

    const opt_string = try options.createOptionsString(arena);

    try spawn(arena, fd[1], &env_map, &.{ mountPoint, "-o", opt_string });

    // Read message with control data from the socket
    var data: [4]u8 = undefined;
    var control: [4 * 256]u8 align(@alignOf(usize)) = undefined;

    var iov = [_]std.posix.iovec{
        std.posix.iovec{
            .base = &data,
            .len = data.len,
        },
    };

    var msg = std.posix.msghdr{
        .name = null,
        .namelen = 0,
        .iov = &iov,
        .iovlen = 1,
        .control = &control,
        .controllen = control.len,
        .flags = 0,
    };

    var res = std.os.linux.recvmsg(fd[0], &msg, 0);
    if (res < 0) {
        return posix.errno(res);
    }

    // Parse control message to extract file descriptor
    if (msg.controllen > 0) {
        // Define cmsghdr structure manually since it might not be exposed
        const cmsghdr = extern struct {
            cmsg_len: usize,
            cmsg_level: c_int,
            cmsg_type: c_int,
        };

        const cmsg_ptr = @as([*]u8, @ptrCast(msg.control));
        const cmsg = @as(*cmsghdr, @ptrCast(@alignCast(cmsg_ptr)));

        const SCM_RIGHTS = 0x01; // SCM_RIGHTS constant for passing file descriptors
        if (cmsg.cmsg_level == std.posix.SOL.SOCKET and cmsg.cmsg_type == SCM_RIGHTS) {
            // Data starts after the header
            const data_offset = @sizeOf(cmsghdr);
            const data_ptr = cmsg_ptr + data_offset;
            const received_fd = @as(*const c_int, @ptrCast(@alignCast(data_ptr))).*;

            res = std.os.linux.fcntl(received_fd, std.os.linux.F.SETFD, std.os.linux.FD_CLOEXEC);
            if (res < 0) {
                return posix.errno(res);
            }

            return received_fd;
        }
    }

    return error.UnexpectedMessage;
}

fn spawn(
    arena: std.mem.Allocator,
    net_fd: posix.fd_t,
    env: *std.process.EnvMap,
    args: []const []const u8,
) !void {
    const null_fd = try posix.openZ("/dev/null", .{ .ACCMODE = .RDWR }, 0);

    const envp = try std.process.createEnvironFromMap(arena, env, .{ .zig_progress_fd = null });

    const argv_buf = try arena.allocSentinel(?[*:0]const u8, args.len + 1, null);
    argv_buf[0] = "fusermount3";
    for (args, 0..) |arg, i| argv_buf[i + 1] = (try arena.dupeZ(u8, arg)).ptr;

    const pid_result = try posix.fork();
    if (pid_result == 0) {
        // This will run in the child
        try std.posix.dup2(null_fd, posix.STDIN_FILENO);
        try std.posix.dup2(null_fd, posix.STDOUT_FILENO);
        try std.posix.dup2(null_fd, posix.STDERR_FILENO);
        try std.posix.dup2(net_fd, 3);

        posix.execvpeZ_expandArg0(.expand, "fusermount3", argv_buf.ptr, envp) catch {};
        posix.exit(1);
    }

    // This will run in the parent
    posix.close(null_fd);

    const res = posix.waitpid(pid_result, 0);
    if (res.status != 0) {
        return error.UnexpectedError;
    }
}
