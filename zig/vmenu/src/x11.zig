const std = @import("std");
const filter_mod = @import("filter.zig");
const Config = @import("config.zig").Config;

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xft/Xft.h");
    @cInclude("X11/extensions/Xinerama.h");
    @cInclude("X11/keysym.h");
});

const PAD: c_int = 8;
const CURSOR_W: c_int = 2;
const MAX_QUERY = 256;

pub const Menu = struct {
    dpy: *c.Display,
    screen: c_int,
    win: c.Window,
    gc: c.GC,
    xdraw: *c.XftDraw,
    font: *c.XftFont,
    visual: *c.Visual,
    colormap: c.Colormap,
    width: c_uint,
    height: c_uint,

    col_bg: c.XftColor,
    col_fg: c.XftColor,
    col_sel_bg: c.XftColor,
    col_sel_fg: c.XftColor,

    items: []const []const u8,
    filtered: [][]const u8,
    query: [MAX_QUERY]u8,
    query_len: usize,
    selected: usize,
    scroll: usize,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, items: []const []const u8, cfg: *const Config) !Menu {
        const dpy = c.XOpenDisplay(null) orelse return error.NoDisplay;
        const screen = c.XDefaultScreen(dpy);
        const root = c.XRootWindow(dpy, screen);
        const visual = c.XDefaultVisual(dpy, screen);
        const colormap = c.XDefaultColormap(dpy, screen);

        // Get screen geometry (Xinerama-aware)
        var sx: c_int = 0;
        var sy: c_int = 0;
        var sw: c_uint = @intCast(c.XDisplayWidth(dpy, screen));
        var sh: c_uint = @intCast(c.XDisplayHeight(dpy, screen));

        if (c.XineramaIsActive(dpy) != 0) {
            var n: c_int = 0;
            const info = c.XineramaQueryScreens(dpy, &n);
            if (info != null and n > 0) {
                sw = @intCast(info[0].width);
                sh = @intCast(info[0].height);
                sx = info[0].x_org;
                sy = info[0].y_org;
                _ = c.XFree(info);
            }
        }

        // Open font
        const font = c.XftFontOpenName(dpy, screen, cfg.font.ptr) orelse return error.NoFont;

        // Window dimensions and centered position
        const win_w: c_uint = cfg.width;
        const win_h: c_uint = cfg.height;
        const win_x: c_int = sx + @divTrunc(@as(c_int, @intCast(sw)) - @as(c_int, @intCast(win_w)), 2);
        const win_y: c_int = sy + @divTrunc(@as(c_int, @intCast(sh)) - @as(c_int, @intCast(win_h)), 2);

        // Allocate colors before creating window (needed for border color)
        var col_bg: c.XftColor = undefined;
        var col_fg: c.XftColor = undefined;
        var col_sel_bg: c.XftColor = undefined;
        var col_sel_fg: c.XftColor = undefined;

        _ = c.XftColorAllocName(dpy, visual, colormap, cfg.bg.ptr,     &col_bg);
        _ = c.XftColorAllocName(dpy, visual, colormap, cfg.fg.ptr,     &col_fg);
        _ = c.XftColorAllocName(dpy, visual, colormap, cfg.sel_bg.ptr, &col_sel_bg);
        _ = c.XftColorAllocName(dpy, visual, colormap, cfg.sel_fg.ptr, &col_sel_fg);

        // Create window with 1px border
        var wa = std.mem.zeroes(c.XSetWindowAttributes);
        wa.override_redirect = c.True;
        wa.event_mask = c.ExposureMask | c.KeyPressMask | c.VisibilityChangeMask;

        const win = c.XCreateWindow(
            dpy, root,
            win_x, win_y, win_w, win_h, 1,
            c.CopyFromParent, c.InputOutput, visual,
            c.CWOverrideRedirect | c.CWEventMask,
            &wa,
        );

        _ = c.XSetWindowBorder(dpy, win, col_sel_bg.pixel);
        _ = c.XSetWindowBackground(dpy, win, col_bg.pixel);

        const gc = c.XCreateGC(dpy, win, 0, null);

        const xdraw = c.XftDrawCreate(dpy, win, visual, colormap) orelse {
            _ = c.XFreeGC(dpy, gc);
            _ = c.XDestroyWindow(dpy, win);
            _ = c.XCloseDisplay(dpy);
            return error.NoXftDraw;
        };

        _ = c.XMapRaised(dpy, win);
        _ = c.XSync(dpy, c.False);

        if (c.XGrabKeyboard(dpy, root, c.True, c.GrabModeAsync, c.GrabModeAsync, c.CurrentTime) != c.GrabSuccess) {
            return error.KeyboardGrabFailed;
        }

        const filtered = try allocator.alloc([]const u8, items.len);
        @memcpy(filtered, items);

        return Menu{
            .dpy      = dpy,
            .screen   = screen,
            .win      = win,
            .gc       = gc,
            .xdraw    = xdraw,
            .font     = font,
            .visual   = visual,
            .colormap = colormap,
            .width    = win_w,
            .height   = win_h,
            .col_bg     = col_bg,
            .col_fg     = col_fg,
            .col_sel_bg = col_sel_bg,
            .col_sel_fg = col_sel_fg,
            .items     = items,
            .filtered  = filtered,
            .query     = [_]u8{0} ** MAX_QUERY,
            .query_len = 0,
            .selected  = 0,
            .scroll    = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(m: *Menu) void {
        c.XftColorFree(m.dpy, m.visual, m.colormap, &m.col_bg);
        c.XftColorFree(m.dpy, m.visual, m.colormap, &m.col_fg);
        c.XftColorFree(m.dpy, m.visual, m.colormap, &m.col_sel_bg);
        c.XftColorFree(m.dpy, m.visual, m.colormap, &m.col_sel_fg);
        c.XftFontClose(m.dpy, m.font);
        c.XftDrawDestroy(m.xdraw);
        _ = c.XFreeGC(m.dpy, m.gc);
        _ = c.XDestroyWindow(m.dpy, m.win);
        _ = c.XCloseDisplay(m.dpy);
    }

    fn rowHeight(m: *Menu) c_int {
        return m.font.*.ascent + m.font.*.descent + 2 * PAD;
    }

    fn visibleCount(m: *Menu) usize {
        const row_h: usize = @intCast(m.rowHeight());
        const list_area: usize = @intCast(@as(c_int, @intCast(m.height)) - m.rowHeight() - 1);
        return list_area / row_h;
    }

    fn textWidth(m: *Menu, text: []const u8) c_int {
        if (text.len == 0) return 0;
        var ext: c.XGlyphInfo = undefined;
        c.XftTextExtentsUtf8(m.dpy, m.font, text.ptr, @intCast(text.len), &ext);
        return @max(0, @as(c_int, ext.xOff));
    }

    fn fillRect(m: *Menu, x: c_int, y: c_int, w: c_uint, h: c_uint, pixel: c_ulong) void {
        _ = c.XSetForeground(m.dpy, m.gc, pixel);
        _ = c.XFillRectangle(m.dpy, m.win, m.gc, x, y, w, h);
    }

    fn drawText(m: *Menu, x: c_int, y: c_int, text: []const u8, color: *c.XftColor) void {
        if (text.len == 0) return;
        c.XftDrawStringUtf8(m.xdraw, color, m.font, x, y, text.ptr, @intCast(text.len));
    }

    pub fn draw(m: *Menu, cfg: *const Config) void {
        const w: c_int         = @intCast(m.width);
        const row_h: c_int     = m.rowHeight();
        const baseline: c_int  = m.font.*.ascent + PAD;

        // Background
        m.fillRect(0, 0, m.width, m.height, m.col_bg.pixel);

        // --- Input row ---
        var x: c_int = 0;

        const prompt = cfg.prompt[0..cfg.prompt.len];
        if (prompt.len > 0) {
            const pw = m.textWidth(prompt);
            m.fillRect(0, 0, @intCast(pw + 2 * PAD), @intCast(row_h), m.col_sel_bg.pixel);
            m.drawText(PAD, baseline, prompt, &m.col_sel_fg);
            x = pw + 2 * PAD;
        }

        const query  = m.query[0..m.query_len];
        const qw     = m.textWidth(query);
        m.drawText(x + PAD, baseline, query, &m.col_fg);
        m.fillRect(x + PAD + qw, PAD / 2, CURSOR_W, @intCast(row_h - PAD), m.col_fg.pixel);

        // Separator below input row
        m.fillRect(0, row_h, @intCast(w), 1, m.col_fg.pixel);

        // --- Item list (vertical) ---
        var item_y: c_int  = row_h + 1;
        var i: usize        = m.scroll;
        while (i < m.filtered.len) : (i += 1) {
            if (item_y + row_h > @as(c_int, @intCast(m.height))) break;

            const item = m.filtered[i];
            if (i == m.selected) {
                m.fillRect(0, item_y, m.width, @intCast(row_h), m.col_sel_bg.pixel);
                m.drawText(PAD, item_y + baseline, item, &m.col_sel_fg);
            } else {
                m.drawText(PAD, item_y + baseline, item, &m.col_fg);
            }
            item_y += row_h;
        }

        _ = c.XFlush(m.dpy);
    }

    fn refilter(m: *Menu) void {
        m.allocator.free(m.filtered);
        m.filtered = filter_mod.filter(m.allocator, m.items, m.query[0..m.query_len]) catch {
            m.filtered = m.allocator.alloc([]const u8, 0) catch &[_][]const u8{};
            return;
        };
        m.selected = 0;
        m.scroll   = 0;
    }

    pub fn run(m: *Menu, cfg: *const Config) ?[]const u8 {
        m.draw(cfg);

        var ev: c.XEvent = undefined;
        while (true) {
            _ = c.XNextEvent(m.dpy, &ev);

            switch (ev.xany.type) {
                c.Expose => {
                    if (ev.xexpose.count == 0) m.draw(cfg);
                },
                c.VisibilityNotify => {
                    if (ev.xvisibility.state != c.VisibilityUnobscured) {
                        _ = c.XRaiseWindow(m.dpy, m.win);
                        _ = c.XFlush(m.dpy);
                    }
                },
                c.KeyPress => {
                    var buf: [32]u8 = undefined;
                    var ks: c.KeySym = undefined;
                    const len = c.XLookupString(&ev.xkey, &buf, buf.len, &ks, null);

                    switch (ks) {
                        c.XK_Return, c.XK_KP_Enter => {
                            if (m.filtered.len > 0) return m.filtered[m.selected];
                            return null;
                        },
                        c.XK_Escape => return null,
                        c.XK_BackSpace => {
                            if (m.query_len > 0) {
                                m.query_len -= 1;
                                m.refilter();
                                m.draw(cfg);
                            }
                        },
                        c.XK_Up => {
                            if (m.selected > 0) {
                                m.selected -= 1;
                                if (m.selected < m.scroll) m.scroll = m.selected;
                                m.draw(cfg);
                            }
                        },
                        c.XK_Down => {
                            if (m.filtered.len > 0 and m.selected + 1 < m.filtered.len) {
                                m.selected += 1;
                                const vis = m.visibleCount();
                                if (m.selected >= m.scroll + vis) m.scroll = m.selected + 1 - vis;
                                m.draw(cfg);
                            }
                        },
                        c.XK_Tab => {
                            if (m.filtered.len > 0) {
                                const sel = m.filtered[m.selected];
                                const n = @min(sel.len, MAX_QUERY);
                                @memcpy(m.query[0..n], sel[0..n]);
                                m.query_len = n;
                                m.refilter();
                                m.draw(cfg);
                            }
                        },
                        else => {
                            if (len > 0) {
                                const ch = buf[0];
                                if (ch >= 32 and ch < 127 and m.query_len < MAX_QUERY - 1) {
                                    m.query[m.query_len] = ch;
                                    m.query_len += 1;
                                    m.refilter();
                                    m.draw(cfg);
                                }
                            }
                        },
                    }
                },
                else => {},
            }
        }
    }
};
