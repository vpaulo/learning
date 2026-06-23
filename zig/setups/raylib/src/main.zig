const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

/// `rl.getColor` only accepts a `u32`. Performing `@intCast` on the return value
/// of `rg.getStyle` invokes checked undefined behavior from Zig when passed to
/// `rl.getColor`, hence the custom implementation here...
fn getColor(hex: i32) rl.Color {
    var color: rl.Color = .black;
    // zig fmt: off
    color.r = @intCast((hex >> 24) & 0xFF);
    color.g = @intCast((hex >> 16) & 0xFF);
    color.b = @intCast((hex >>  8) & 0xFF);
    color.a = @intCast((hex >>  0) & 0xFF);
    // zig fmt: on
    return color;
}

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true, .vsync_hint = true });
    rl.initWindow(400, 200, "raygui - controls test suite");
    defer rl.closeWindow();

    // rl.setTargetFPS(60); // vsync_hint syncs with monitor display rate :)
    rl.setWindowMinSize(400, 200);
    const font = try rl.loadFontEx("assets/JetBrainsMonoNerdFontMono-Regular.ttf", 32, null);
    defer rl.unloadFont(font);

    // rl.setTextureFilter(font.texture, rl.TextureFilter.bilinear);

    rg.setStyle(.default, .{ .default = .text_size }, 16);
    rg.setStyle(.default, .{ .default = .text_spacing }, 2);
    // Tell raygui to use this font
    rg.setFont(font);

    var show_message_box = false;

    const color_int = rg.getStyle(.default, .{ .default = .background_color });

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(getColor(color_int));
        rl.drawFPS(300, 10);

        if (rg.button(.init(24, 24, 150, 30), "#191#Show Message"))
            show_message_box = true;

        if (show_message_box) {
            const result = rg.messageBox(
                .init(85, 70, 250, 100),
                "#191#Message Box",
                "Hi! This is a message",
                "Nice;Cool",
            );

            if (result >= 0) show_message_box = false;
        }

        // Draw text using the loaded font, Extra spacing = more GPU work. Spacing 0–2 is ideal.
        rl.drawTextEx(
            font,
            "Hello from a custom font!",
            .{ .x = 24, .y = 180 },
            16, // font size
            2, // spacing
            rl.Color.black,
        );
    }
}

// fn drawTextCentered(
//     font: rl.Font,
//     text: []const u8,
//     center: rl.Vector2,
//     size: f32,
//     spacing: f32,
//     color: rl.Color,
// ) void {
//     const dims = rl.MeasureTextEx(font, text, size, spacing);

//     rl.DrawTextEx(
//         font,
//         text,
//         .{
//             .x = center.x - dims.x / 2,
//             .y = center.y - dims.y / 2,
//         },
//         size,
//         spacing,
//         color,
//     );
// }

// fn drawTextWrapped(
//     font: rl.Font,
//     text: []const u8,
//     pos: rl.Vector2,
//     max_width: f32,
//     size: f32,
//     spacing: f32,
//     color: rl.Color,
// ) void {
//     var x = pos.x;
//     var y = pos.y;

//     var it = std.mem.split(u8, text, " ");
//     while (it.next()) |word| {
//         const word_size = rl.MeasureTextEx(font, word, size, spacing);

//         if (x + word_size.x > pos.x + max_width) {
//             x = pos.x;
//             y += size + spacing;
//         }

//         rl.DrawTextEx(font, word, .{ .x = x, .y = y }, size, spacing, color);
//         x += word_size.x + rl.MeasureTextEx(font, " ", size, spacing).x;
//     }
// }

// drawTextWrapped(
//     fonts.get(.body),
//     "This is a wrapped paragraph of text that respects a max width.",
//     .{ .x = 100, .y = 100 },
//     400,
//     24,
//     1,
//     rl.BLACK,
// );
