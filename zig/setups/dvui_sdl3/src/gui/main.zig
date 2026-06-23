const Main = @This();

const std = @import("std");
const dvui = @import("dvui");
const HostBar = @import("views/bar.zig");
const Gui = @import("../gui.zig");
const Core = @import("../core.zig");

subviews: struct {
    host_bar: HostBar = .{},
} = .{},

pub fn draw(main: *Main, core: *Core, active_scene: *Gui.ActiveScene) !void {
    _ = active_scene;
    main.subviews.host_bar.draw(core);

    {
        var vbox = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .both,
            .background = true,
        });
        defer vbox.deinit();

        dvui.labelNoFmt(@src(), "Main", .{}, .{
            .gravity_x = 0.5,
            // .expand = .horizontal,
            .font = .theme(.title),
        });
    }
}
