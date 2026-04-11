const std = @import("std");

pub const base_64 = struct {
    table: *const [64]u8,

    pub fn init() base_64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const numbers = "0123456789+/";

        return base_64{
            .table = upper ++ lower ++ numbers,
        };
    }

    fn char_at(self: base_64, index: u8) u8 {
        return self.table[index];
    }

    fn char_index(self: base_64, char: u8) u8 {
        if (char == '=') return 64;

        var i: u8 = 0;
        var output_index: u8 = 0;

        while (i < 64) : (i += 1) {
            if (self.char_at(i) == char) break;
            output_index += 1;
        }
        return output_index;
    }

    pub fn encode(self: base_64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const n_output = try calc_encode_length(input);
        var output = try allocator.alloc(u8, n_output);
        var tmp_buffer = [3]u8{ 0, 0, 0 };
        var count: u8 = 0;
        var output_index: usize = 0;

        for (input, 0..) |_, i| {
            tmp_buffer[count] = input[i];
            count += 1;
            if (count == 3) {
                output[output_index] = self.char_at(tmp_buffer[0] >> 2);
                output[output_index + 1] = self.char_at(((tmp_buffer[0] & 0x03) << 4) + (tmp_buffer[1] >> 4));
                output[output_index + 2] = self.char_at(((tmp_buffer[1] & 0x0f) << 2) + (tmp_buffer[2] >> 6));
                output[output_index + 3] = self.char_at(tmp_buffer[2] & 0x3f);
                output_index += 4;
                count = 0;
            }
        }

        if (count == 1) {
            output[output_index] = self.char_at(tmp_buffer[0] >> 2);
            output[output_index + 1] = self.char_at((tmp_buffer[0] & 0x03) << 4);
            output[output_index + 2] = '=';
            output[output_index + 3] = '=';
        }

        if (count == 2) {
            output[output_index] = self.char_at(tmp_buffer[0] >> 2);
            output[output_index + 1] = self.char_at(((tmp_buffer[0] & 0x03) << 4) + (tmp_buffer[1] >> 4));
            output[output_index + 2] = self.char_at((tmp_buffer[1] & 0x0f) << 2);
            output[output_index + 3] = '=';
            output_index += 4;
        }

        return output;
    }

    pub fn decode(self: base_64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const n_output = try calc_decode_length(input);
        var tmp_buffer = [4]u8{ 0, 0, 0, 0 };
        var output = try allocator.alloc(u8, n_output);
        var count: u8 = 0;
        var output_index: u64 = 0;
        for (0..output.len) |i| {
            output[i] = 0;
        }

        for (0..input.len) |i| {
            tmp_buffer[count] = self.char_index(input[i]);
            count += 1;
            if (count == 4) {
                output[output_index] = (tmp_buffer[0] << 2) + (tmp_buffer[1] >> 4);
                if (tmp_buffer[2] != 64) {
                    output[output_index + 1] = (tmp_buffer[1] << 4) + (tmp_buffer[2] >> 2);
                }
                if (tmp_buffer[3] != 64) {
                    output[output_index + 2] = (tmp_buffer[2] << 6) + tmp_buffer[3];
                }
                output_index += 3;
                count = 0;
            }
        }

        return output;
    }
};

fn calc_encode_length(input: []const u8) !usize {
    if (input.len < 3) {
        return 4;
    }

    const n_output: usize = try std.math.divCeil(usize, input.len, 3);
    return n_output * 4;
}

fn calc_decode_length(input: []const u8) !usize {
    if (input.len < 4) {
        return 3;
    }

    const n_groups: usize = try std.math.divFloor(usize, input.len, 4);
    var multiple_groups: usize = n_groups * 3;

    var i: usize = input.len - 1;
    while (i > 0) : (i -= 1) {
        if (input[i] == '=') {
            multiple_groups -= 1;
        } else {
            break;
        }
    }

    return multiple_groups;
}
