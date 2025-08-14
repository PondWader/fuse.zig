const std = @import("std");
const assert = std.debug.assert;

/// Joins multiple slices with a single allocation.
///
/// `size` MUST be less than the total number of slices that will be appended.
pub fn SliceJoiner(comptime T: type, comptime capacity: comptime_int, sep: []const u8) type {
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
            if (self.current_idx == 0) {
                return &.{};
            }

            var res = try allocator.alloc(T, self.result_size + sep.len * (self.current_idx - 1));
            var offset: usize = 0;
            var i: usize = 0;
            while (i < self.current_idx) : (i += 1) {
                const slice = self.slices[i];
                @memcpy(res[offset..], slice);
                offset += slice.len;
                if (i != self.current_idx - 1) {
                    @memcpy(res[offset..], sep);
                    offset += sep.len;
                }
            }

            std.debug.assert(offset == self.result_size);

            return res;
        }
    };
}
