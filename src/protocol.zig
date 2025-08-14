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

pub const HeaderIn = packed struct {
    len: u32,

    opcode: u32,
    unique: u64,
    nodeid: u64,

    uid: u32,
    gid: u32,
    pid: u32,
    padding: u32,
};

pub const HeaderOut = packed struct {
    len: u32,
    @"error": i32,
    unique: u64,
};

pub const InitIn = packed struct {
    major: u32,
    minor: u32,
    max_readahead: u32,
    flags: u32,
    flags2: u32,
    unused1: u32 = undefined,
    unused2: u32 = undefined,
    unused3: u32 = undefined,
    unused4: u32 = undefined,
    unused5: u32 = undefined,
    unused6: u32 = undefined,
    unused7: u32 = undefined,
    unused8: u32 = undefined,
    unused9: u32 = undefined,
    unused10: u32 = undefined,
    unused11: u32 = undefined,
};

pub const InitOut = packed struct {
    major: u32,
    minor: u32,
    max_readahead: u32,
    flags: u32,
    max_background: u16,
    congestion_threshold: u16,
    max_write: u32,
    time_gran: u32,
    unused1: u32 = undefined,
    unused2: u32 = undefined,
    unused3: u32 = undefined,
    unused4: u32 = undefined,
    unused5: u32 = undefined,
    unused6: u32 = undefined,
    unused7: u32 = undefined,
    unused8: u32 = undefined,
    unused9: u32 = undefined,
};

pub const GetattrIn = packed struct {
    getattr_flags: u32,
    dummy: u32,
    fh: u64,
};

pub const Attr = packed struct {
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

pub const AttrOut = packed struct {
    attr_valid: u64,
    attr_valid_nsec: u32,
    dummy: u32,
    attr: Attr,
};

pub const AccessIn = packed struct {
    mask: u32,
    padding: u32,
};

pub const OpenIn = packed struct {
    flags: u32,
    unused: u32,
};

pub const OpenOut = packed struct {
    fh: u64,
    open_flags: u32,
    padding: u32,
};

pub const ReadIn = packed struct {
    fh: u64,
    offset: u64,
    size: u32,
    read_flags: u32,
    lock_owner: u64,
    flags: u32,
    padding: u32,
};

pub const WriteIn = packed struct {
    fh: u64,
    offset: u64,
    size: u32,
    write_flags: u32,
    lock_owner: u64,
    flags: u32,
    padding: u32,
};

pub const WriteOut = packed struct {
    size: u32,
    padding: u32,
};

pub const InterruptIn = packed struct {
    unique: u64,
};

pub const EntryOut = packed struct {
    nodeid: u64,
    generation: u64,
    entry_valid: u64,
    attr_valid: u64,
    entry_valid_nsec: u32,
    attr_valid_nsec: u32,
    attr: Attr,
};

pub const FlushIn = packed struct {
    fh: u64,
    unused: u32,
    padding: u32,
    lock_owner: u64,
};

pub const ReleaseIn = packed struct {
    fh: u64,
    flags: u32,
    release_flags: u32,
    lock_owner: u64,
};

pub const ReleaseOut = packed struct {};

pub const Kstatfs = packed struct {
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

pub const StatfsOut = packed struct {
    st: Kstatfs,
};
