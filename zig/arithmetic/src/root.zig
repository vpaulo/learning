const std = @import("std");

pub const NUMBER_OF_QUESTIONS = 20;
pub const key_list = "+-x/";

//  Here's what the value means mechanically: every time you get a question wrong, both operands involved
//  get WRONG_PENALTY = 5 extra "tickets" in a weighted lottery. The next time get_random runs, it picks a
//  random number in the range [0, max_value + total_penalty). Values below max_value are plain random; values at
//  or above fall into the penalty list — so each wrong number gets 5 extra chances to be picked again.

//  Each time a penalised number is selected, its ticket count drops by 1. So a number you got wrong will
//  appear roughly 5 extra times before its bias fades away.
const WRONG_PENALTY = 5;

/// Linked-list node for the penalty system.
/// Numbers that were answered incorrectly are stored here and weighted
/// to appear more often in subsequent questions.
const PenaltyNode = struct {
    /// The number (operand or result) that was answered incorrectly.
    number: i32,
    /// How many more times this node can be selected before it is removed.
    remaining_uses: i32,
    next: ?*PenaltyNode,
};

/// All mutable game state, replacing the C globals.
pub const GameState = struct {
    allocator: std.mem.Allocator,
    /// The operation characters the game will ask about (subset of "+-x/").
    operations: []const u8,
    /// Upper bound for operands; operands are picked from [0, range_max].
    range_max: i32,
    correct_count: u32,
    wrong_count: u32,
    /// Total seconds spent answering correctly (used to compute time-per-question).
    elapsed_seconds: i64,
    /// Sum of all remaining_uses across penalty nodes, indexed by [operation][operand_pos].
    /// operand_pos 0 = left operand (or result for - and /), 1 = right operand.
    penalty_totals: [4][2]i32,
    /// Head of the penalty linked list for each [operation][operand_pos].
    penalty_lists: [4][2]?*PenaltyNode,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: std.mem.Allocator, operations: []const u8, range_max: i32, seed: u64) GameState {
        return .{
            .allocator = allocator,
            .operations = operations,
            .range_max = range_max,
            .correct_count = 0,
            .wrong_count = 0,
            .elapsed_seconds = 0,
            .penalty_totals = std.mem.zeroes([4][2]i32),
            .penalty_lists = std.mem.zeroes([4][2]?*PenaltyNode),
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Free all penalty list nodes.
    pub fn deinit(self: *GameState) void {
        for (0..4) |op_index| {
            for (0..2) |operand_pos| {
                var current = self.penalty_lists[op_index][operand_pos];
                while (current) |node| {
                    const next_node = node.next;
                    self.allocator.destroy(node);
                    current = next_node;
                }
            }
        }
    }

    /// Print correct/wrong/score and time-per-question stats to stdout.
    pub fn show_stats(self: *const GameState) void {
        const total_attempts = self.correct_count + self.wrong_count;
        if (total_attempts > 0) {
            const score_percent = 100 * self.correct_count / total_attempts;
            print("\n\nRights {d}; Wrongs {d}; Score {d}%", .{ self.correct_count, self.wrong_count, score_percent });
            if (self.correct_count > 0) {
                const seconds_per_question: f64 = @as(f64, @floatFromInt(self.elapsed_seconds)) /
                    @as(f64, @floatFromInt(self.correct_count));
                print("\nTotal time {d} seconds; {d:.1} seconds per problem\n\n", .{ self.elapsed_seconds, seconds_per_question });
            }
        }
        print("\n", .{});
    }

    /// Map an operation character (+-x/) to its index in key_list (0-3).
    pub fn get_operation_index(op: u8) usize {
        return std.mem.indexOfScalar(u8, key_list, op) orelse
            std.debug.panic("arithmetic: bug: op '{c}' not in key_list\n", .{op});
    }

    /// Add a wrong-answer penalty for `number` to the list for `op` / `operand_pos`.
    pub fn penalise(self: *GameState, number: i32, op: u8, operand_pos: usize) !void {
        const op_index = get_operation_index(op);
        const new_node = try self.allocator.create(PenaltyNode);
        new_node.* = .{
            .number = number,
            .remaining_uses = WRONG_PENALTY,
            .next = self.penalty_lists[op_index][operand_pos],
        };
        self.penalty_lists[op_index][operand_pos] = new_node;
        self.penalty_totals[op_index][operand_pos] += WRONG_PENALTY;
    }

    /// Return a random value in [0, max_value) biased toward previously wrong answers.
    /// The total lottery pool is max_value + penalty_totals, so penalised numbers
    /// get extra chances proportional to their remaining_uses count.
    pub fn get_random(self: *GameState, max_value: i32, op: u8, operand_pos: usize) i32 {
        const op_index = get_operation_index(op);
        const weighted_range: u32 = @intCast(max_value + self.penalty_totals[op_index][operand_pos]);
        const pick: i32 = @intCast(self.rng.random().uintLessThan(u32, weighted_range));

        // Pick lands in the plain range — return it directly.
        if (pick < max_value) return pick;

        // Pick lands in the penalty zone — find which penalty node owns this position.
        var position = pick - max_value;
        var list_ptr = &self.penalty_lists[op_index][operand_pos];
        while (list_ptr.*) |node| {
            if (node.remaining_uses > position) {
                const selected_number = node.number;
                self.penalty_totals[op_index][operand_pos] -= 1;
                node.remaining_uses -= 1;
                // Remove the node once all its uses are exhausted.
                if (node.remaining_uses <= 0) {
                    list_ptr.* = node.next;
                    self.allocator.destroy(node);
                }
                return selected_number;
            }
            position -= node.remaining_uses;
            list_ptr = &node.next;
        }

        std.debug.panic("arithmetic: bug: inconsistent penalties\n", .{});
    }

    /// Ask one question. Returns false on EOF, true otherwise.
    /// Keeps re-asking the same question until the correct answer is given.
    pub fn problem(self: *GameState) !bool {
        const operation = self.operations[self.rng.random().uintLessThan(u32, @intCast(self.operations.len))];

        var left: i32 = undefined;
        var right: i32 = undefined;
        var result: i32 = undefined;

        // For non-division ops, right is chosen once and held across retries.
        // This mirrors C's placement of get_random() before the retry label.
        if (operation != '/') {
            right = self.get_random(self.range_max + 1, operation, 1);
        }

        // Regenerate operands until no overflow (negative values) occurs.
        while (true) {
            switch (operation) {
                '+' => {
                    left = self.get_random(self.range_max + 1, operation, 0);
                    result = left + right;
                },
                '-' => {
                    // Pick result first; derive left from it so subtraction stays in range.
                    result = self.get_random(self.range_max + 1, operation, 0);
                    left = right + result;
                },
                'x' => {
                    left = self.get_random(self.range_max + 1, operation, 0);
                    result = left * right;
                },
                '/' => {
                    // right >= 1 so the divisor is never zero.
                    right = self.get_random(self.range_max, operation, 1) + 1;
                    result = self.get_random(self.range_max + 1, operation, 0);
                    // Add a random remainder so that left / right == result exactly.
                    const remainder: i32 = @intCast(self.rng.random().uintLessThan(u32, @intCast(right)));
                    left = right * result + remainder;
                },
                else => unreachable,
            }
            if (result >= 0 and left >= 0) break;
        }

        print("{d} {c} {d} =   ", .{ left, operation, right });

        const start_time = std.time.timestamp();
        var line_buf: [80]u8 = undefined;

        while (true) {
            const raw_input = readLine(&line_buf) catch {
                print("\n", .{});
                return false;
            };
            const input = raw_input orelse {
                print("\n", .{});
                return false;
            };

            // Skip leading whitespace.
            var digit_start: usize = 0;
            while (digit_start < input.len and std.ascii.isWhitespace(input[digit_start])) digit_start += 1;

            if (digit_start >= input.len or !std.ascii.isDigit(input[digit_start])) {
                print("Please type a number.\n", .{});
                continue;
            }

            // Find where the digit run ends (matches C's atoi behaviour: stops at first non-digit).
            var digit_end = digit_start;
            while (digit_end < input.len and std.ascii.isDigit(input[digit_end])) digit_end += 1;

            const answer = std.fmt.parseInt(i32, input[digit_start..digit_end], 10) catch {
                print("Please type a number.\n", .{});
                continue;
            };

            if (answer == result) {
                print("Right!\n", .{});
                self.correct_count += 1;
                break;
            }

            // Wrong answer: penalise both operands (or result) and ask again.
            print("What?\n", .{});
            self.wrong_count += 1;
            try self.penalise(right, operation, 1);
            if (operation == 'x' or operation == '+') {
                try self.penalise(left, operation, 0);
            } else {
                try self.penalise(result, operation, 0);
            }
        }

        const finish_time = std.time.timestamp();
        self.elapsed_seconds += finish_time - start_time;
        return true;
    }
};

// ---------------------------------------------------------------------------
// Private I/O helpers
// ---------------------------------------------------------------------------

/// Format and write to stdout. Uses a stack buffer; silently drops output on
/// overflow (prompts are always short).
fn print(comptime fmt: []const u8, args: anytype) void {
    var output_buf: [512]u8 = undefined;
    const formatted = std.fmt.bufPrint(&output_buf, fmt, args) catch return;
    std.fs.File.stdout().writeAll(formatted) catch {};
}

/// Read one line from stdin into `buf`, stripping the trailing newline.
/// Returns null on EOF, the line slice otherwise.
fn readLine(buf: []u8) !?[]u8 {
    const stdin = std.fs.File.stdin();
    var len: usize = 0;
    while (len < buf.len) {
        var byte_buf: [1]u8 = undefined;
        const bytes_read = try stdin.read(&byte_buf);
        if (bytes_read == 0) return if (len == 0) null else buf[0..len]; // EOF
        if (byte_buf[0] == '\n') return buf[0..len];
        if (byte_buf[0] != '\r') { // strip \r for Windows-style line endings
            buf[len] = byte_buf[0];
            len += 1;
        }
    }
    return buf[0..len]; // buffer full — return what we have
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "get_operation_index maps +-x/ to 0-3" {
    try std.testing.expectEqual(@as(usize, 0), GameState.get_operation_index('+'));
    try std.testing.expectEqual(@as(usize, 1), GameState.get_operation_index('-'));
    try std.testing.expectEqual(@as(usize, 2), GameState.get_operation_index('x'));
    try std.testing.expectEqual(@as(usize, 3), GameState.get_operation_index('/'));
}

test "GameState init and deinit" {
    const allocator = std.testing.allocator;
    var state = GameState.init(allocator, "+-", 10, 42);
    defer state.deinit();
    try std.testing.expectEqual(@as(u32, 0), state.correct_count);
    try std.testing.expectEqual(@as(u32, 0), state.wrong_count);
}

test "penalise increases penalty sum" {
    const allocator = std.testing.allocator;
    var state = GameState.init(allocator, "+-", 10, 42);
    defer state.deinit();
    try state.penalise(7, '+', 1);
    try std.testing.expectEqual(@as(i32, WRONG_PENALTY), state.penalty_totals[0][1]);
}
