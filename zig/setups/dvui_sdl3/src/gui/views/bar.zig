const Bar = @This();

const dvui = @import("dvui");
const Core = @import("../../core.zig");

pub fn draw(hb: *Bar, core: *Core) void {
    _ = hb;

    core.failure = .none; // TODO: remove

    var bar = dvui.scrollArea(
        @src(),
        .{},
        .{
            .expand = .vertical,
            // .color_fill = .{ .name = .fill_window },
        },
    );
    defer bar.deinit();

    dvui.labelNoFmt(@src(), "Sidebar", .{}, .{
        .gravity_x = 0.5,
        // .expand = .horizontal,
        .font = .theme(.title),
    });
}
