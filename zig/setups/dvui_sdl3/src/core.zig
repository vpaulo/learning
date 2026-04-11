const Core = @This();

const builtin = @import("builtin");
const std = @import("std");
// const assert = std.debug.assert;
const log = std.log.scoped(.core);
const Allocator = std.mem.Allocator;

gpa: Allocator,
/// Set to true once data has been loaded from disk.
loaded: std.atomic.Value(bool) = .init(false),

/// Set to an error message when the core logic encounters an unrecoverable error.
/// The application should show an error dialog and shutdown when this happens.
failure: UnrecoverableFailure = .none,

pub const UnrecoverableFailure = union(enum) {
    none,
    // TODO: add errors as needed
};

// This init function should be kept lightweight, we run it in the main thread
// and it blocks showing the initial spinner animation. Core.run will perform
// secondary initialization in a separate thread.
pub fn init(
    gpa: Allocator,
) !Core {
    return .{
        .gpa = gpa,
    };
}

// Should only denit what is inited in init().
// Resources inited in Core.run should be deinited by Core.run.
pub fn deinit(core: *Core) void {
    _ = core;
}

pub fn run(core: *Core) void {
    log.debug("started", .{});
    defer log.debug("goodbye", .{});

    // Done loading, we can now show the main application screen.
    core.loaded.store(true, .unordered);
}
