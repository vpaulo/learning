const Gui = @This();

const dvui = @import("dvui");
const Core = @import("core.zig");

active_scene: ActiveScene = .main,
scenes: struct {
    empty: @import("gui/empty.zig") = .{},
    main: @import("gui/main.zig") = .{},
} = .{},

pub const ActiveScene = enum {
    main,
    empty,
};

pub fn draw(gui: *Gui, core: *Core) !void {
    var main_box = dvui.box(
        @src(),
        .{ .dir = .horizontal },
        .{
            .expand = .both,
            .background = true,
        },
    );
    defer main_box.deinit();

    // Special case to load a specific scene and skip normal drawing
    // if (condition == 0) {
    //     try gui.scenes.empty.draw(core);
    //     return;
    // }

    switch (gui.active_scene) {
        .main => try gui.scenes.main.draw(core, &gui.active_scene),
        else => try gui.scenes.empty.draw(),
    }
}
