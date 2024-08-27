const std = @import("std");
const w4 = @import("w4");

var prng = std.Random.DefaultPrng.init(0);
const random = prng.random();

const Game = struct {
    scene: enum {
        menu,
        play,
        over,

        const Self = @This();

        fn next(self: Self) Self {
            return switch (self) {
                .menu => .play,
                .play => .over,
                .over => .menu,
            };
        }
    } = .play,

    disk: Disk = .{ .starts = 0 },

    dice: [5]Die = .{
        die(1, 1, 60, 30, 30),
        die(2, 33, 60, 30, 30),
        die(3, 65, 60, 30, 30),
        die(4, 97, 60, 30, 30),
        die(5, 129, 60, 30, 30),
    },

    playPalette: [4]u32,
    menuPalette: [4]u32,
    overPalette: [4]u32,

    playerCount: u3 = 1,

    u: u3 = 0,

    mouse: w4.Mouse = .{},
    button: w4.Button = .{},

    nextBtn: Rect = .{
        .x = 130,
        .y = 148,
        .width = 20,
        .height = 10,
    },

    rollBtn: Rect = .{
        .x = 96,
        .y = 125,
        .width = 58,
        .height = 30,
    },

    fn start(self: *Game) void {
        w4.SYSTEM_FLAGS.* = w4.SYSTEM_HIDE_GAMEPAD_OVERLAY;

        _ = self.disk.increment();

        for (&self.dice) |*d| {
            if (!d.h) d.startRoll();

            for (0..(@intCast(self.disk.starts))) |_| {
                _ = random.int(i32);
            }
        }
    }

    fn update(self: *Game) void {
        self.mouse.update();
        self.button.update();

        switch (self.scene) {
            .menu => self.menu(),
            .play => self.play(),
            .over => self.over(),
        }
    }

    fn menu(self: *Game) void {
        w4.palette(self.menuPalette);

        if (self.button.released(0, w4.BUTTON_UP)) self.playerCount +|= 1;
        if (self.button.released(0, w4.BUTTON_DOWN) and self.playerCount > 1) self.playerCount -|= 1;

        w4.color(0x13);
        w4.text("-==[ 10K GAME ]==-", 8, 20);

        w4.color(0x13);
        sany(10, 140, .{ "Player Count:", self.playerCount });

        if (self.nextBtn.contains(&self.mouse)) {
            if (self.mouse.released(w4.MOUSE_LEFT)) self.next();

            w4.color(0x22);
        } else {
            w4.color(0x21);
        }

        self.nextBtn.draw();
    }

    fn play(self: *Game) void {
        w4.palette(self.playPalette);

        var held: usize = 0;

        for (&self.dice) |*d| {
            if (d.h) held += 1;
        }

        const shouldStartRoll =
            self.button.released(0, w4.BUTTON_1) or
            self.mouse.released(w4.MOUSE_RIGHT) or
            (held < 5 and self.rollBtn.clicked(&self.mouse, w4.MOUSE_LEFT));

        for (&self.dice) |*d| {
            d.update(&self.mouse);

            if (shouldStartRoll) {
                if (!d.h) d.startRoll();
            }

            d.draw();
        }

        if (held < 5) {
            w4.color(0x34);
            self.rollBtn.draw();
            w4.color(0x41);
            sany(self.rollBtn.x + 4, self.rollBtn.y + 12, .{ "ROLL ", 5 - held });
        }
    }

    fn over(self: *Game) void {
        w4.palette(self.overPalette);

        w4.color(0x13);
        w4.text("OVER!", 10, 20);

        if (self.nextBtn.contains(&self.mouse)) {
            if (self.mouse.released(w4.MOUSE_LEFT)) self.next();
            w4.color(0x22);
        } else {
            w4.color(0x32);
        }
        self.nextBtn.draw();
    }

    fn next(self: *Game) void {
        const n = self.scene.next();

        switch (n) {
            .menu => {
                self.playerCount = 1;
            },
            .play => {},
            .over => {},
        }

        self.scene = n;
    }
};

const Die = struct {
    h: bool = false,
    n: u3 = 0,
    l: u5 = 0,
    r: Rect,

    fn startRoll(d: *Die) void {
        d.l = 10 + @mod(random.int(u5), 21);
    }

    fn roll(d: *Die) void {
        d.n = @mod(random.int(u3), 6) + 1;
    }

    fn toggle(d: *Die) void {
        d.h = !d.h;
    }

    fn update(d: *Die, m: *w4.Mouse) void {
        if (d.r.clicked(m, w4.MOUSE_LEFT)) {
            d.toggle();
        }

        d.l -|= 1;

        if (d.l > 0 and @mod(d.l, 2) == 0) d.roll();
    }

    fn draw(d: *Die) void {
        const dot = w4.circle;
        const s = 4;
        const r = d.r;

        w4.color(if (!d.h) 0x43 else 0x32);

        // Draw the rectangle itself
        r.draw();

        // Corners of the die
        w4.color(1);
        w4.pixel(r.x, r.y);
        w4.pixel(r.x + 29, r.y);
        w4.pixel(r.x, r.y + 29);
        w4.pixel(r.x + 29, r.y + 29);

        if (!d.h) {
            w4.color(0x13);
            w4.text(" R ", r.x + 4, r.y - 10);
        }

        // Dots of the die
        w4.color(if (!d.h) 0x12 else 0x34);

        switch (d.n) {
            1 => {
                dot(r.x + 15, r.y + 15, s); // center center
            },
            2 => {
                dot(r.x + 6, r.y + 24, s); // left bottom
                dot(r.x + 24, r.y + 6, s); // right top
            },
            3 => {
                dot(r.x + 6, r.y + 24, s); // left bottom
                dot(r.x + 15, r.y + 15, s); // center center
                dot(r.x + 24, r.y + 6, s); // right top
            },
            4 => {
                dot(r.x + 6, r.y + 6, s); // left top
                dot(r.x + 6, r.y + 24, s); // left bottom
                dot(r.x + 24, r.y + 6, s); // right top
                dot(r.x + 24, r.y + 24, s); // right bottom
            },
            5 => {
                dot(r.x + 6, r.y + 6, s); // left top
                dot(r.x + 6, r.y + 24, s); // left bottom
                dot(r.x + 15, r.y + 15, s); // center center
                dot(r.x + 24, r.y + 6, s); // right top
                dot(r.x + 24, r.y + 24, s); // right bottom
            },
            6 => {
                dot(r.x + 6, r.y + 6, s); // left top
                dot(r.x + 6, r.y + 15, s); // left center
                dot(r.x + 6, r.y + 24, s); // left bottom
                dot(r.x + 24, r.y + 6, s); // right top
                dot(r.x + 24, r.y + 15, s); // right center
                dot(r.x + 24, r.y + 24, s); // right bottom
            },
            else => {},
        }

        w4.color(if (!d.h) 2 else 3);
        any(r.x + 11, r.y + 32, .{d.n});
    }
};

const Rect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    fn clicked(self: Rect, m: *w4.Mouse, btn: u8) bool {
        if (!self.contains(m)) return false;

        return m.released(btn);
    }

    fn contains(self: Rect, m: *w4.Mouse) bool {
        const xw = self.x + @as(i32, @intCast(self.width));
        const yh = self.y + @as(i32, @intCast(self.height));

        return m.x >= self.x and m.x <= xw and m.y >= self.y and m.y <= yh;
    }

    fn draw(self: Rect) void {
        w4.rect(self.x, self.y, self.width, self.height);
    }
};

var game = Game{
    .playPalette = penNpaper,
    .menuPalette = .{ penNpaper[3], penNpaper[2], penNpaper[1], penNpaper[0] },
    .overPalette = .{ penNpaper[1], penNpaper[0], penNpaper[3], penNpaper[2] },
};

export fn start() void {
    game.start();
}

export fn update() void {
    game.update();
}

// 640 ought to be enough for anybody.
var memory: [640]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&memory);
const allocator = fba.allocator();

// pen n paper Palette
//
// a simple gb palette to make games look handrawn :)
//
// https://lospec.com/palette-list/pen-n-paper
//
const penNpaper = .{
    0xa4929a,
    0xe4dbba,
    0x4f3a54,
    0x260d1c,
};

fn format(x: i32, y: i32, comptime fmt: []const u8, args: anytype) void {
    const str = std.fmt.allocPrint(allocator, fmt, args) catch "";
    defer allocator.free(str);

    w4.text(str, x, y);
}

fn any(x: i32, y: i32, args: anytype) void {
    format(x, y, "{any}", args);
}

fn sany(x: i32, y: i32, args: anytype) void {
    format(x, y, "{s}{any}", args);
}

fn rect(x: i32, y: i32, width: u32, height: u32) Rect {
    return .{ .x = x, .y = y, .width = width, .height = height };
}

fn die(n: u3, x: i32, y: i32, width: u32, height: u32) Die {
    return .{ .n = n, .r = rect(x, y, width, height) };
}

const Disk = struct {
    starts: usize,

    fn increment(d: *Disk) usize {
        _ = d.load();
        d.starts += 1;
        _ = d.save();
        return d.starts;
    }

    fn load(d: *Disk) u32 {
        return w4.diskr(@ptrCast(d), @sizeOf(@TypeOf(d)));
    }

    fn save(d: *Disk) u32 {
        return w4.diskw(@ptrCast(d), @sizeOf(@TypeOf(d)));
    }
};
