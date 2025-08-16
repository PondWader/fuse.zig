pub const Opcode = enum(u32) {
    LOOKUP = 1,
    FORGET = 2,
    GETATTR = 3,
    SETATTR = 4,
    READLINK = 5,
    SYMLINK = 6,
    MKNOD = 8,
    MKDIR = 9,
    UNLINK = 10,
    RMDIR = 11,
    RENAME = 12,
    LINK = 13,
    OPEN = 14,
    READ = 15,
    WRITE = 16,
    STATFS = 17,
    RELEASE = 18,
    FSYNC = 20,
    SETXATTR = 21,
    GETXATTR = 22,
    LISTXATTR = 23,
    REMOVEXATTR = 24,
    FLUSH = 25,
    INIT = 26,
    OPENDIR = 27,
    READDIR = 28,
    RELEASEDIR = 29,
    FSYNCDIR = 30,
    GETLK = 31,
    SETLK = 32,
    SETLKW = 33,
    ACCESS = 34,
    CREATE = 35,
    INTERRUPT = 36,
    BMAP = 37,
    DESTROY = 38,
    IOCTL = 39,
    POLL = 40,
    NOTIFY_REPLY = 41,
    BATCH_FORGET = 42,
    FALLOCATE = 43, // protocol version 19
    READDIRPLUS = 44, // protocol version 21
    RENAME2 = 45, // protocol version 23
    LSEEK = 46, // protocol version 24
    COPY_FILE_RANGE = 47, // protocol version 28
    _,
};

pub const HeaderIn = extern struct {
    len: u32,

    opcode: u32,
    unique: u64,
    nodeid: u64,

    uid: u32,
    gid: u32,
    pid: u32,
    padding: u32,
};

pub const HeaderOut = extern struct {
    len: u32,
    @"error": i32,
    unique: u64,
};

pub const InitIn = extern struct {
    major: u32,
    minor: u32,
    max_readahead: u32,
    flags: u32,
    flags2: u32,
    unused: [11]u32 = undefined,

    pub fn get_flags(self: @This()) CapFlags {
        return @bitCast(@as(u64, self.flags) | @as(u64, self.flags2) << 32);
    }
};

pub const InitOut = extern struct {
    major: u32,
    minor: u32,
    max_readahead: u32,
    flags: u32,
    max_background: u16,
    congestion_threshold: u16,
    max_write: u32,
    time_gran: u32,
    max_pages: u16,
    map_alignment: u16,
    flags2: u32,
    max_stack_depth: u32,
    request_timeout: u16,
    unused: [11]u16 = undefined,
};

pub const GetattrIn = extern struct {
    getattr_flags: u32,
    dummy: u32,
    fh: u64,
};

pub const Attr = extern struct {
    ino: u64,
    size: u64,
    blocks: u64,
    atime: u64,
    mtime: u64,
    ctime: u64,
    atimensec: u32,
    mtimensec: u32,
    ctimensec: u32,
    mode: u32,
    nlink: u32,
    uid: u32,
    gid: u32,
    rdev: u32,
    blksize: u32,
    padding: u32,
};

pub const AttrOut = extern struct {
    attr_valid: u64,
    attr_valid_nsec: u32,
    dummy: u32,
    attr: Attr,
};

pub const AccessIn = extern struct {
    mask: u32,
    padding: u32,
};

pub const OpenIn = extern struct {
    flags: u32,
    unused: u32,
};

pub const OpenOut = extern struct {
    fh: u64,
    open_flags: u32,
    padding: u32,
};

pub const ReadIn = extern struct {
    fh: u64,
    offset: u64,
    size: u32,
    read_flags: u32,
    lock_owner: u64,
    flags: u32,
    padding: u32,
};

pub const WriteIn = extern struct {
    fh: u64,
    offset: u64,
    size: u32,
    write_flags: u32,
    lock_owner: u64,
    flags: u32,
    padding: u32,
};

pub const WriteOut = extern struct {
    size: u32,
    padding: u32,
};

pub const InterruptIn = extern struct {
    unique: u64,
};

pub const EntryOut = extern struct {
    nodeid: u64,
    generation: u64,
    entry_valid: u64,
    attr_valid: u64,
    entry_valid_nsec: u32,
    attr_valid_nsec: u32,
    attr: Attr,
};

pub const FlushIn = extern struct {
    fh: u64,
    unused: u32,
    padding: u32,
    lock_owner: u64,
};

pub const ReleaseIn = extern struct {
    fh: u64,
    flags: u32,
    release_flags: u32,
    lock_owner: u64,
};

pub const ReleaseOut = extern struct {};

pub const Kstatfs = extern struct {
    blocks: u64,
    bfree: u64,
    bavail: u64,
    files: u64,
    ffree: u64,
    bsize: u32,
    namelen: u32,
    frsize: u32,
    padding: u32,
    unused1: u32 = undefined,
    unused2: u32 = undefined,
    unused3: u32 = undefined,
    unused4: u32 = undefined,
    unused5: u32 = undefined,
    unused6: u32 = undefined,
};

pub const StatfsOut = extern struct {
    st: Kstatfs,
};

/// Flags are used to declare capabilities of the fuse filesystem daemon.
pub const CapFlags = packed struct(u64) {
    /// Indicates that the filesystem supports asynchronous read requests.
    ///
    /// If this capability is not requested/available, the kernel will
    /// ensure that there is at most one pending read request per
    /// file-handle at any time, and will attempt to order read requests by
    /// increasing offset.
    ASYNC_READ: bool = true,

    /// Indicates that the filesystem supports "remote" locking.
    POSIX_LOCKS: bool = false,

    /// Kernel sends file handle for fstat, etc... (not yet supported)
    FILE_OPS: bool = false,

    /// Indicates that the filesystem supports the O_TRUNC open flag. If
    /// disabled, and an application specifies O_TRUNC, fuse first calls
    /// truncate() and then open() with O_TRUNC filtered out.
    ATOMIC_O_TRUNC: bool = true,

    /// Indicates that the filesystem supports lookups of "." and "..".
    ///
    /// When this flag is set, the filesystem must be prepared to receive requests
    /// for invalid inodes (i.e., for which a FORGET request was received or
    /// which have been used in a previous instance of the filesystem daemon) and
    /// must not reuse node-ids (even when setting generation numbers).
    EXPORT_SUPPORT: bool = false,

    /// Filesystem can handle write size larger than 4kB
    BIG_WRITES: bool = false,

    /// Indicates that the kernel should not apply the umask to the
    /// file mode on create operations.
    DONT_MASK: bool = false,

    /// Indicates that libfuse should try to use splice() when writing to
    /// the fuse device. This may improve performance.
    SPLICE_WRITE: bool = false,

    /// Indicates that libfuse should try to move pages instead of copying when
    /// writing to / reading from the fuse device. This may improve performance.
    ///
    /// This feature is disabled by default.
    SPLICE_MOVE: bool = false,

    /// Indicates that libfuse should try to use splice() when reading from
    /// the fuse device. This may improve performance.
    ///
    /// This feature is enabled by default when supported by the kernel and
    /// if the filesystem implements a write_buf() handler.
    SPLICE_READ: bool = false,

    /// If set, the calls to flock(2) will be emulated using POSIX locks and must
    /// then be handled by the filesystem's setlock() handler.
    ///
    /// If not set, flock(2) calls will be handled by the FUSE kernel module
    /// internally (so any access that does not go through the kernel cannot be taken
    /// into account).
    FLOCK_LOCKS: bool = false,

    /// Indicates that the filesystem supports ioctl's on directories.
    HAS_IOCTL_DIR: bool = true,

    /// Traditionally, while a file is open the FUSE kernel module only
    /// asks the filesystem for an update of the file's attributes when a
    /// client attempts to read beyond EOF. This is unsuitable for
    /// e.g. network filesystems, where the file contents may change
    /// without the kernel knowing about it.
    ///
    /// If this flag is set, FUSE will check the validity of the attributes
    /// on every read. If the attributes are no longer valid (i.e., if the
    /// *attr_timeout* passed to fuse_reply_attr() or set in `struct
    /// fuse_entry_param` has passed), it will first issue a `getattr`
    /// request. If the new mtime differs from the previous value, any
    /// cached file *contents* will be invalidated as well.
    ///
    /// This flag should always be set when available. If all file changes
    /// go through the kernel, *attr_timeout* should be set to a very large
    /// number to avoid unnecessary getattr() calls.
    AUTO_INVAL_DATA: bool = true,

    /// Indicates that the filesystem supports readdirplus.
    DO_READDIRPLUS: bool = false,

    /// Indicates that the filesystem supports adaptive readdirplus.
    ///
    /// If FUSE_CAP_READDIRPLUS is not set, this flag has no effect.
    ///
    /// If FUSE_CAP_READDIRPLUS is set and this flag is not set, the kernel
    /// will always issue readdirplus() requests to retrieve directory
    /// contents.
    ///
    /// If FUSE_CAP_READDIRPLUS is set and this flag is set, the kernel
    /// will issue both readdir() and readdirplus() requests, depending on
    /// how much information is expected to be required.
    ///
    /// As of Linux 4.20, the algorithm is as follows: when userspace
    /// starts to read directory entries, issue a READDIRPLUS request to
    /// the filesystem. If any entry attributes have been looked up by the
    /// time userspace requests the next batch of entries continue with
    /// READDIRPLUS, otherwise switch to plain READDIR. This will result
    /// in eg plain "ls" triggering READDIRPLUS first then READDIR after
    /// that because it doesn't do lookups. "ls -l" should result in all
    /// READDIRPLUS, except if dentries are already cached.
    ///
    /// This feature is enabled by default when supported by the kernel and
    /// if the filesystem implements both a readdirplus() and a readdir()
    /// handler.
    READDIRPLUS_AUTO: bool = false,

    /// Indicates that the filesystem supports asynchronous direct I/O submission.
    ///
    /// If this capability is not requested/available, the kernel will ensure that
    /// there is at most one pending read and one pending write request per direct
    /// I/O file-handle at any time.
    ASYNC_DIO: bool = true,

    /// Indicates that writeback caching should be enabled. This means that
    /// individual write request may be buffered and merged in the kernel
    /// before they are send to the filesystem.
    WRITEBACK_CACHE: bool = false,

    /// Indicates support for zero-message opens. If this flag is set in
    /// the `capable` field of the `fuse_conn_info` structure, then the
    /// filesystem may return `ENOSYS` from the open() handler to indicate
    /// success. Further attempts to open files will be handled in the
    /// kernel. (If this flag is not set, returning ENOSYS will be treated
    /// as an error and signaled to the caller).
    ///
    /// Setting this flag in the `want` field enables this behavior automatically
    /// within libfuse for low level API users. If non-low level users wish to have
    /// this behavior you must return `ENOSYS` from the open() handler on supporting
    /// kernels.
    NO_OPEN_SUPPORT: bool = false,

    /// Indicates support for parallel directory operations. If this flag
    /// is unset, the FUSE kernel module will ensure that lookup() and
    /// readdir() requests are never issued concurrently for the same
    /// directory.
    PARALLEL_DIROPS: bool = false,

    /// Indicates that the filesystem is responsible for unsetting
    /// setuid and setgid bits when a file is written, truncated, or
    /// its owner is changed.
    HANDLE_KILLPRIV: bool = false,

    /// Indicates support for POSIX ACLs.
    ///
    /// If this feature is enabled, the kernel will cache and have
    /// responsibility for enforcing ACLs. ACL will be stored as xattrs and
    /// passed to userspace, which is responsible for updating the ACLs in
    /// the filesystem, keeping the file mode in sync with the ACL, and
    /// ensuring inheritance of default ACLs when new filesystem nodes are
    /// created. Note that this requires that the file system is able to
    /// parse and interpret the xattr representation of ACLs.
    ///
    /// Enabling this feature implicitly turns on the
    /// ``default_permissions`` mount option (even if it was not passed to
    /// mount(2)).
    POSIX_ACL: bool = false,

    /// Reading the device after abort returns ECONNABORTED
    ABORT_ERROR: bool = false,

    /// init_out.max_pages contains the max number of req pages
    MAX_PAGES: bool = false,

    /// Indicates that the kernel supports caching symlinks in its page cache.
    ///
    /// When this feature is enabled, symlink targets are saved in the page cache.
    /// You can invalidate a cached link by calling:
    /// `fuse_lowlevel_notify_inval_inode(se, ino, 0, 0);`
    ///
    /// If the kernel supports it (>= 4.20), you can enable this feature by
    /// setting this flag in the `want` field of the `fuse_conn_info` structure.
    CACHE_SYMLINKS: bool = false,

    /// Indicates support for zero-message opendirs. If this flag is set in
    /// the `capable` field of the `fuse_conn_info` structure, then the filesystem
    /// may return `ENOSYS` from the opendir() handler to indicate success. Further
    /// opendir and releasedir messages will be handled in the kernel. (If this
    /// flag is not set, returning ENOSYS will be treated as an error and signalled
    /// to the caller.)
    ///
    /// Setting this flag in the `want` field enables this behavior automatically
    /// within libfuse for low level API users. If non-low level users with to have
    /// this behavior you must return `ENOSYS` from the opendir() handler on
    /// supporting kernels.
    NO_OPENDIR_SUPPORT: bool = false,

    /// Indicates support for invalidating cached pages only on explicit request.
    ///
    /// If this flag is set in the `capable` field of the `fuse_conn_info` structure,
    /// then the FUSE kernel module supports invalidating cached pages only on
    /// explicit request by the filesystem through fuse_lowlevel_notify_inval_inode()
    /// or fuse_invalidate_path().
    ///
    /// By setting this flag in the `want` field of the `fuse_conn_info` structure,
    /// the filesystem is responsible for invalidating cached pages through explicit
    /// requests to the kernel.
    ///
    /// Note that setting this flag does not prevent the cached pages from being
    /// flushed by OS itself and/or through user actions.
    ///
    /// Note that if both FUSE_CAP_EXPLICIT_INVAL_DATA and FUSE_CAP_AUTO_INVAL_DATA
    /// are set in the `capable` field of the `fuse_conn_info` structure then
    /// FUSE_CAP_AUTO_INVAL_DATA takes precedence.
    EXPLICIT_INVAL_DATA: bool = false,

    /// InitOut.map_alignment contains log2(byte alignment) for
    /// foffset and moffset fields in struct
    /// fuse_setupmapping_out and fuse_removemapping_one.
    /// NOTE: You should leave this as false if you're using the default init handler.
    MAP_ALIGNMENT: bool = false,

    /// Kernel supports auto-mounting directory submounts
    SUBMOUNTS: bool = false,

    /// Indicates that the filesystem is responsible for unsetting
    /// setuid and setgid bit and additionally cap (stored as xattr) when a
    /// file is written, truncated, or its owner is changed.
    /// Upon write/truncate suid/sgid is only killed if caller
    /// does not have CAP_FSETID. Additionally upon
    /// write/truncate sgid is killed only if file has group
    /// execute permission. (Same as Linux VFS behavior).
    /// KILLPRIV_V2 requires handling of
    ///   - FUSE_OPEN_KILL_SUIDGID (set in struct fuse_create_in::open_flags)
    ///   - FATTR_KILL_SUIDGID (set in struct fuse_setattr_in::valid)
    ///   - FUSE_WRITE_KILL_SUIDGID (set in struct fuse_write_in::write_flags)
    HANDLE_KILLPRIV_V2: bool = false,

    /// Indicates that an extended 'struct fuse_setxattr' is used by the kernel
    /// side - extra_flags are passed, which are used (as of now by acl) processing.
    /// For example FUSE_SETXATTR_ACL_KILL_SGID might be set.
    SETXATTR_EXT: bool = false,

    /// Extended fuse_init_in request
    INIT_EXT: bool = false,

    /// Reserved, do not use
    INIT_RESERVED: bool = false,

    /// Add security context to create, mkdir, symlink, and mknod
    SECURITY_CTX: bool = false,

    /// Use per inode DAX
    HAS_INODE_DAX: bool = false,

    /// Add supplementary group info to create, mkdir,
    /// symlink and mknod (single group that matches parent)
    CREATE_SUPP_GROUP: bool = false,

    /// Indicates support that dentries can be expired.
    ///
    /// Expiring dentries, instead of invalidating them, makes a difference for
    /// overmounted dentries, where plain invalidation would detach all submounts
    /// before dropping the dentry from the cache. If only expiry is set on the
    /// dentry, then any overmounts are left alone and until ->d_revalidate()
    /// is called.
    ///
    /// Note: ->d_revalidate() is not called for the case of following a submount,
    /// so invalidation will only be triggered for the non-overmounted case.
    /// The dentry could also be mounted in a different mount instance, in which case
    /// any submounts will still be detached.
    HAS_EXPIRE_ONLY: bool = false,

    /// Files opened with FUSE_DIRECT_IO do not support MAP_SHARED mmap. This restriction
    /// is relaxed through FUSE_CAP_DIRECT_IO_RELAX (kernel flag: FUSE_DIRECT_IO_RELAX).
    /// MAP_SHARED is disabled by default for FUSE_DIRECT_IO, as this flag can be used to
    /// ensure coherency between mount points (or network clients) and with kernel page
    /// cache as enforced by mmap that cannot be guaranteed anymore.
    DIRECT_IO_ALLOW_MMAP: bool = false,

    /// Indicates support for passthrough mode access for read/write operations.
    ///
    /// If enabled, then the FUSE kernel module supports redirecting read/write
    /// operations to the backing file instead of letting them to be handled
    /// by the FUSE daemon.
    PASSTHROUGH: bool = false,

    /// Indicates that the file system cannot handle NFS export
    ///
    /// If this flag is set NFS export and name_to_handle_at
    /// is not going to work at all and will fail with EOPNOTSUPP.
    NO_EXPORT_SUPPORT: bool = false,

    /// Kernel supports resending pending requests, and the high bit
    /// of the request ID indicates resend requests
    HAS_RESEND: bool = false,

    /// Allow creation of idmapped mounts
    ALLOW_IDMAP: bool = false,

    /// Indicates support for io-uring between fuse-server and fuse-client
    OVER_IO_URING: bool = true,

    /// Kernel supports timing out requests.
    /// init_out.request_timeout contains the timeout (in secs)
    REQUEST_TIMEOUT: bool = false,

    _: u21 = undefined,

    pub fn merge(self: @This(), other: @This()) @This() {
        return @bitCast(@as(u64, @bitCast(self)) & @as(u64, @bitCast(other)));
    }
};
