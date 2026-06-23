const std = @import("std");

fn indexOfCaseInsensitive(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len > haystack.len) return null;
    const limit = haystack.len - needle.len + 1;
    outer: for (0..limit) |i| {
        for (needle, 0..) |nc, j| {
            if (std.ascii.toLower(haystack[i + j]) != std.ascii.toLower(nc)) continue :outer;
        }
        return i;
    }
    return null;
}

pub fn filter(
    allocator: std.mem.Allocator,
    items: []const []const u8,
    query: []const u8,
) ![][]const u8 {
    if (query.len == 0) {
        const copy = try allocator.alloc([]const u8, items.len);
        @memcpy(copy, items);
        return copy;
    }
    var result: std.ArrayList([]const u8) = .empty;
    for (items) |item| {
        if (indexOfCaseInsensitive(item, query) != null) {
            try result.append(allocator, item);
        }
    }
    return result.toOwnedSlice(allocator);
}
