const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");

const Gui = @import("gui.zig");
pub const Core = @import("core.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.client);

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800.0, .h = 600.0 },
            .min_size = .{ .w = 250.0, .h = 350.0 },
            .title = "Basic",
            // .icon = @embedFile("appicon"),
            .window_init_options = .{
                .theme = dvui.Theme.builtin.adwaita_dark,
            },
        },
    },
    .frameFn = frame,
    .initFn = init,
    .deinitFn = deinit,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

var global_app_singleton: App = undefined;

fn init(window: *dvui.Window) !void {
    return global_app_singleton.init(window);
}

fn deinit() void {}

pub const App = struct {
    gui: Gui = .{},
    core: Core,
    window: *dvui.Window,

    fn init(app: *App, window: *dvui.Window) void {
        const gpa = window.gpa;

        app.* = .{
            .window = window,
            .core = Core.init(
                gpa,
            ) catch |err| {
                std.process.fatal("unable to init core: {t}", .{err});
            },
        };

        // Run the initial load of DBs, servers, anything that is needed to start the app
        app.core.run();
    }
};

fn frame() !dvui.App.Result {
    const app = &global_app_singleton;
    const core = &app.core;

    if (checkClosing()) return .close;
    if (!core.loaded.load(.unordered)) return initialLoadingFrame();

    if (core.failure != .none) return .close;
    try app.gui.draw(core);
    return .ok;
}

fn checkClosing() bool {
    const win = dvui.currentWindow();
    const wd = win.data();
    for (dvui.events()) |*e| {
        if (!dvui.eventMatchSimple(e, wd)) continue;
        if ((e.evt == .window and e.evt.window.action == .close) or (e.evt == .app and e.evt.app.action == .quit)) {
            e.handle(@src(), wd);
            log.debug("shutting down from ui", .{});
            return true;
        }
    }

    return false;
}

fn initialLoadingFrame() !dvui.App.Result {
    var main_box = dvui.box(
        @src(),
        .{ .dir = .vertical },
        .{ .expand = .both, .background = true },
    );
    defer main_box.deinit();

    // While performing the initial load, we display a spinner.
    // Synchronization for the initial load happens via an atomic enum
    // because locking the entire state right now would either hang or
    // slow down the initial setup process.
    dvui.spinner(@src(), .{
        .gravity_x = 0.5,
        .gravity_y = 0.5,
        .expand = .both,
    });
    return .ok;
}
