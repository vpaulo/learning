const std = @import("std");
const config_mod = @import("config.zig");
const x11_mod = @import("x11.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    // Read all items from stdin
    var content: std.ArrayList(u8) = .empty;
    var tmp: [4096]u8 = undefined;
    while (true) {
        const n = try std.posix.read(std.posix.STDIN_FILENO, &tmp);
        if (n == 0) break;
        try content.appendSlice(allocator, tmp[0..n]);
    }

    std.debug.print(">> {s}.\n", .{content.items});

    var items: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, content.items, '\n');
    while (it.next()) |line| {
        const trimmed = if (line.len > 0 and line[line.len - 1] == '\r') line[0 .. line.len - 1] else line;
        if (trimmed.len > 0) try items.append(allocator, trimmed);
    }

    if (items.items.len == 0) return;

    // Load config
    const cfg = config_mod.load(allocator);

    // Run X11 menu
    var menu = try x11_mod.Menu.init(allocator, items.items, &cfg);
    defer menu.deinit();

    if (menu.run(&cfg)) |selected| {
        _ = std.c.write(std.posix.STDOUT_FILENO, selected.ptr, selected.len);
        _ = std.c.write(std.posix.STDOUT_FILENO, "\n", 1);
    }
}
