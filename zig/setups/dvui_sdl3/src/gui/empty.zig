const Empty = @This();

const dvui = @import("dvui");

pub fn draw(empty: *Empty) !void {
    _ = empty;

    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .gravity_x = 0.5,
        .gravity_y = 0.5,
        .expand = .horizontal,
    });
    defer box.deinit();

    dvui.labelNoFmt(@src(), "Welcome", .{}, .{
        .gravity_x = 0.5,
        // .expand = .horizontal,
        .font = .theme(.title),
    });
}
