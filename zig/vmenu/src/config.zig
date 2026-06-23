const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

pub const Config = struct {
    font: [:0]const u8,
    bg: [:0]const u8,
    fg: [:0]const u8,
    sel_bg: [:0]const u8,
    sel_fg: [:0]const u8,
    prompt: [:0]const u8,
    width: u32,
    height: u32,
};

pub const defaults = Config{
    .font = "monospace:size=10",
    .bg = "#222222",
    .fg = "#bbbbbb",
    .sel_bg = "#005577",
    .sel_fg = "#eeeeee",
    .prompt = "> ",
    .width = 400,
    .height = 300,
};

fn getString(lua: *Lua, name: [:0]const u8, allocator: std.mem.Allocator) ?[:0]const u8 {
    _ = lua.getGlobal(name);
    defer lua.pop(1);
    if (lua.typeOf(-1) != .string) return null;
    const s = lua.toString(-1) catch return null;
    return allocator.dupeZ(u8, s) catch null;
}

fn getUint(lua: *Lua, name: [:0]const u8) ?u32 {
    _ = lua.getGlobal(name);
    defer lua.pop(1);
    if (lua.typeOf(-1) != .number) return null;
    const n = lua.toNumber(-1) catch return null;
    if (n < 0) return null;
    return @intFromFloat(n);
}

pub fn load(allocator: std.mem.Allocator) Config {
    const home_ptr = std.c.getenv("HOME") orelse return defaults;
    const home = std.mem.span(home_ptr);
    const path = std.fs.path.join(allocator, &.{ home, ".config", "vmenu", "config.lua" }) catch return defaults;
    defer allocator.free(path);

    const path_z = allocator.dupeZ(u8, path) catch return defaults;
    defer allocator.free(path_z);

    var lua = Lua.init(allocator) catch return defaults;
    defer lua.deinit();
    lua.openLibs();
    lua.doFile(path_z) catch return defaults;

    var cfg = defaults;
    if (getString(lua, "font", allocator)) |v| cfg.font = v;
    if (getString(lua, "bg", allocator)) |v| cfg.bg = v;
    if (getString(lua, "fg", allocator)) |v| cfg.fg = v;
    if (getString(lua, "sel_bg", allocator)) |v| cfg.sel_bg = v;
    if (getString(lua, "sel_fg", allocator)) |v| cfg.sel_fg = v;
    if (getString(lua, "prompt", allocator)) |v| cfg.prompt = v;
    if (getUint(lua, "width"))  |v| cfg.width  = v;
    if (getUint(lua, "height")) |v| cfg.height = v;
    return cfg;
}
