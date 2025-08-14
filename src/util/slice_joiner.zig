const std = @import("std");
const assert = std.debug.assert;

/// Joins multiple slices with a single allocation.
///
/// `size` MUST be less than the total number of slices that will be appended.
pub fn SliceJoiner(comptime T: type, comptime capacity: comptime_int) type {
    return struct {
        slices: [capacity][]const T = undefined,
        current_idx: usize = 0,
        result_size: usize = 0,

        pub fn append(self: *@This(), slice: []const T) void {
            std.debug.assert(self.current_idx < capacity);

            self.slices[self.current_idx] = slice;
            self.current_idx += 1;
            self.result_size += slice.len;
        }

        pub fn result(self: *@This(), allocator: std.mem.Allocator) ![]T {
            var res = try allocator.alloc(T, self.result_size);
            var offset: usize = 0;
            var i: usize = 0;
            while (i < self.current_idx) : (i += 1) {
                const slice = self.slices[i];
                @memcpy(res[offset .. offset + slice.len], slice);
                offset += slice.len;
            }

            std.debug.assert(offset == res.len);

            return res;
        }
    };
}
