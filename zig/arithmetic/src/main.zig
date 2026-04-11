const std = @import("std");
const game = @import("arithmetic");

/// Global pointer used by the SIGINT handler to print stats before exiting.
/// Signal handlers cannot capture closures, so this must be a global.
var game_state: ?*game.GameState = null;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Defaults matching the original C program.
    var operations: []const u8 = "+-";
    var range_max: i32 = 10;

    var args = std.process.args();
    _ = args.next(); // skip executable name

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-o")) {
            const ops = args.next() orelse usage();
            if (ops.len == 0) usage();
            for (ops) |c| {
                if (std.mem.indexOfScalar(u8, game.key_list, c) == null) {
                    std.debug.print("arithmetic: unknown key.\n", .{});
                    std.process.exit(1);
                }
            }
            operations = ops;
        } else if (std.mem.eql(u8, arg, "-r")) {
            const range_str = args.next() orelse usage();
            range_max = std.fmt.parseInt(i32, range_str, 10) catch {
                std.debug.print("arithmetic: invalid range.\n", .{});
                std.process.exit(1);
            };
            if (range_max <= 0) {
                std.debug.print("arithmetic: invalid range.\n", .{});
                std.process.exit(1);
            }
        } else {
            usage();
        }
    }

    const seed: u64 = @bitCast(std.time.timestamp());
    var state = game.GameState.init(allocator, operations, range_max, seed);
    defer state.deinit();

    // Register SIGINT handler so Ctrl-C prints stats before exiting.
    game_state = &state;
    const action = std.posix.Sigaction{
        .handler = .{ .handler = sigint_handler },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &action, null);

    // Main game loop: every NUMBER_OF_QUESTIONS, print statistics.
    while (true) {
        for (0..game.NUMBER_OF_QUESTIONS) |_| {
            const cont = try state.problem();
            if (!cont) return;
        }
        state.show_stats();
    }
}

fn sigint_handler(_: c_int) callconv(.c) void {
    if (game_state) |gs| gs.show_stats();
    std.process.exit(0);
}

fn usage() noreturn {
    std.debug.print("usage: arithmetic [-o +-x/] [-r range]\n", .{});
    std.process.exit(1);
}
