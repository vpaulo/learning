const std = @import("std");
const ende = @import("ende");

const stdout = std.fs.File.stdout();
const print = std.debug.print;

pub fn main() !void {
    var memory_buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory_buffer);
    const allocator = fba.allocator();

    const text = "Testing some more stuff";
    const etext = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";

    const base64 = ende.base_64.init();
    const encoded_text = try base64.encode(allocator, text);
    const decoded_text = try base64.decode(allocator, etext);

    print("Encoded text: {s}\n", .{encoded_text});
    print("Decoded text: {s}\n", .{decoded_text});
    print("Encoded length: {d}\n", .{encoded_text.len});
    print("Decoded length: {d}\n", .{decoded_text.len});
}
