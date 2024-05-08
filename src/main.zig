const std = @import("std");
const ray = @import("raylib.zig");

const GameOfLife = struct {
    width: u8,
    height: u8,
    length: u16,
    cells: std.ArrayList(u8),
    tmpCells: std.ArrayList(u8),

    pub fn display(self: GameOfLife) !void {
        const stdout = std.io.getStdOut().writer();

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                try stdout.print("{d}", .{self.cellState(@intCast(x), @intCast(y))});
            }
            _ = try stdout.write("\n");
        }
    }

    pub fn init(width: u8, height: u8, allocator: std.mem.Allocator) !GameOfLife {
        const length: u16 = @as(u16, width) * @as(u16, height);
        var cells = try std.ArrayList(u8).initCapacity(allocator, length);
        var tmpCells = try std.ArrayList(u8).initCapacity(allocator, length);
        try cells.appendNTimes(0, length);
        try tmpCells.appendNTimes(0, length);
        return GameOfLife{ .width = width, .height = height, .length = length, .cells = cells, .tmpCells = tmpCells };
    }

    pub fn deinit(self: GameOfLife) void {
        self.cells.deinit();
        self.tmpCells.deinit();
    }

    pub fn step(self: GameOfLife) void {
        @memcpy(self.tmpCells.items, self.cells.items);

        for (0..self.height) |y| {
            const yPos = self.width * y;
            for (0..self.width) |x| {
                const pos = yPos + x;
                const currCell = self.tmpCells.items[pos];
                // Cell is not alive and has no neighbors SKIP!
                if (currCell == 0) {
                    continue;
                }
                const neighbors = currCell >> 1;
                const isAlive: bool = (currCell & 0x01) != 0;

                if ((neighbors < 2) and isAlive) {
                    self.clearCell(@intCast(x), @intCast(y));
                } else if ((neighbors > 3) and isAlive) {
                    self.clearCell(@intCast(x), @intCast(y));
                } else if ((neighbors == 2 and isAlive) or (neighbors == 3 and isAlive)) {
                    // nop mabe remove?
                } else if ((neighbors == 3) and !isAlive) {
                    self.setCell(@intCast(x), @intCast(y));
                }
            }
        }

        // @memcpy(self.cells.items, self.tmpCells.items);
    }

    fn computeOffsets(self: GameOfLife, x: u8, y: u8) [4]i32 {
        var xLeft: i32, var xRight: i32, var yAbove: i32, var yBelow: i32 = .{ 0, 0, 0, 0 };
        xLeft = if (x == 0) self.width - 1 else -1;
        xRight = if (x == (self.width - 1)) -@as(i32, (self.width - 1)) else 1;
        yAbove = if (y == 0) self.length - self.width else -@as(i32, self.width);
        yBelow = if (y == (self.height - 1)) -@as(i32, (self.length - self.width)) else self.width;

        return .{ xLeft, xRight, yAbove, yBelow };
    }

    pub fn setCell(self: GameOfLife, x: u8, y: u8) void {
        const xLeft, const xRight, const yAbove, const yBelow = computeOffsets(self, x, y);

        const baseLocation: i32 = (@as(u16, y) * @as(u16, self.width)) + @as(u16, x);
        const ptr: *u8 = &self.cells.items[@intCast(baseLocation)];
        if ((ptr.* & 0x01) == 1) return;
        ptr.* |= 0x01;

        var tmp: usize = @intCast(baseLocation + (yAbove + xLeft));
        self.cells.items[tmp] += 0x02;
        tmp = @intCast(baseLocation + yAbove);
        self.cells.items[tmp] += 0x02;

        tmp = @intCast(baseLocation + (yAbove + xRight));
        self.cells.items[tmp] += 0x02;
        tmp = @intCast(baseLocation + xLeft);
        self.cells.items[tmp] += 0x02;
        tmp = @intCast(baseLocation + xRight);
        self.cells.items[tmp] += 0x02;
        tmp = @intCast(baseLocation + yBelow + xLeft);
        self.cells.items[tmp] += 0x02;
        tmp = @intCast(baseLocation + yBelow);
        self.cells.items[tmp] += 0x02;
        tmp = @intCast(baseLocation + yBelow + xRight);
        self.cells.items[tmp] += 0x02;
    }

    pub fn clearCell(self: GameOfLife, x: u8, y: u8) void {
        const xLeft, const xRight, const yAbove, const yBelow = computeOffsets(self, x, y);

        const baseLocation: i32 = (@as(u16, y) * @as(u16, self.width)) + @as(u16, x);
        const ptr: *u8 = &self.cells.items[@intCast(baseLocation)];
        ptr.* &= ~@as(u8, 0x01);

        var tmp: usize = @intCast(baseLocation + (yAbove + xLeft));
        self.cells.items[tmp] -= 0x02;
        tmp = @intCast(baseLocation + yAbove);
        self.cells.items[tmp] -= 0x02;

        tmp = @intCast(baseLocation + (yAbove + xRight));
        self.cells.items[tmp] -= 0x02;
        tmp = @intCast(baseLocation + xLeft);
        self.cells.items[tmp] -= 0x02;
        tmp = @intCast(baseLocation + xRight);
        self.cells.items[tmp] -= 0x02;
        tmp = @intCast(baseLocation + yBelow + xLeft);
        self.cells.items[tmp] -= 0x02;
        tmp = @intCast(baseLocation + yBelow);
        self.cells.items[tmp] -= 0x02;
        tmp = @intCast(baseLocation + yBelow + xRight);
        self.cells.items[tmp] -= 0x02;
    }

    pub fn cellState(self: GameOfLife, x: u8, y: u8) u8 {
        const ptr = self.cells.items[(@as(u16, y) * @as(u16, self.width)) + @as(u16, x)];
        return ptr & 0x01;
    }

    pub fn cellNeighbors(self: GameOfLife, x: u8, y: u8) u8 {
        const ptr = self.cells.items[(@as(u16, y) * @as(u16, self.width)) + @as(u16, x)];
        return ptr >> 1;
    }
};

pub fn main() !void {
    try ray_main();
}

fn ray_main() !void {
    // const monitor = ray.GetCurrentMonitor();
    // const width = ray.GetMonitorWidth(monitor);
    // const height = ray.GetMonitorHeight(monitor);
    const width = 800;
    const height = 800;

    const cW = 30;
    const cH = 30;

    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT | ray.FLAG_VSYNC_HINT);
    ray.InitWindow(width, height, "zig raylib example");
    defer ray.CloseWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 8 }){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .leak => @panic("leaked memory"),
            else => {},
        }
    }

    const gol = try GameOfLife.init(cW, cH, allocator);
    defer gol.deinit();
    // std.log.info("gol {any}", .{gol.cells});
    try gol.display();
    gol.setCell(0, 1);
    gol.setCell(0, 2);
    gol.setCell(1, 1);
    gol.setCell(1, 2);
    std.log.info("Set 4 cells", .{});
    try gol.display();
    gol.step();
    std.log.info("Took a step", .{});
    try gol.display();
    // std.log.info("gol {any}", .{gol.cells});

    const rectSize: f32 = width / cW;

    const colors = [_]ray.Color{ ray.GRAY, ray.RED, ray.GOLD, ray.LIME, ray.BLUE, ray.VIOLET, ray.BROWN };
    const colors_len: i32 = @intCast(colors.len);
    var current_color: i32 = 2;
    var hint = true;
    var isActive = false;

    while (!ray.WindowShouldClose()) {
        // input
        var delta: i2 = 0;
        if (ray.IsKeyPressed(ray.KEY_UP)) delta += 1;
        if (ray.IsKeyPressed(ray.KEY_DOWN)) delta -= 1;
        if (delta != 0) {
            current_color = @mod(current_color + delta, colors_len);
            hint = false;
        }
        if (ray.IsKeyPressed(ray.KEY_SPACE)) isActive = !isActive;
        if (ray.IsKeyPressed(ray.KEY_RIGHT)) gol.step();

        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            const mx: f32 = @floatFromInt(ray.GetMouseX());
            const my: f32 = @floatFromInt(ray.GetMouseY());

            for (0..gol.height) |y| {
                for (0..gol.width) |x| {
                    const xStart = @as(f32, @floatFromInt(x)) * rectSize;
                    const yStart = @as(f32, @floatFromInt(y)) * rectSize;
                    const xEnd = @as(f32, @floatFromInt(x + 1)) * rectSize;
                    const yEnd = @as(f32, @floatFromInt(y + 1)) * rectSize;
                    if ((xStart <= mx) and (xEnd >= mx) and yStart <= my and yEnd >= my) {
                        std.log.info("Clicked x {d} y {d}", .{ x, y });
                        const ux: u8 = @intCast(x);
                        const uy: u8 = @intCast(y);
                        var cN = gol.cellNeighbors(ux, uy);
                        var cS = gol.cellState(ux, uy);
                        std.log.info("Cell information before set. Status {d} Neighbors {d}", .{ cS, cN });
                        gol.setCell(@intCast(x), @intCast(y));

                        cN = gol.cellNeighbors(ux, uy);
                        cS = gol.cellState(ux, uy);
                        std.log.info("Cell information after set. Status {d} Neighbors {d}", .{ cS, cN });
                    }
                }
            }
        }

        if (isActive) gol.step();

        // draw
        {
            ray.BeginDrawing();
            defer ray.EndDrawing();

            ray.ClearBackground(colors[@intCast(current_color)]);
            // if (hint) ray.DrawText("press up or down arrow to change background color", 120, 140, 20, ray.BLUE);
            // ray.DrawText("Congrats! You created your first window!", 190, 200, 20, ray.BLACK);

            for (0..gol.height) |y| {
                for (0..gol.width) |x| {
                    const rect = ray.Rectangle{ .x = @as(f32, @floatFromInt(x)) * rectSize, .y = @as(f32, @floatFromInt(y)) * rectSize, .width = rectSize, .height = rectSize };
                    const color = if (gol.cellState(@intCast(x), @intCast(y)) == 1) ray.GREEN else ray.GRAY;
                    ray.DrawRectangleRec(rect, color);
                }
            }

            // now lets use an allocator to create some dynamic text
            // pay attention to the Z in `allocPrintZ` that is a convention
            // for functions that return zero terminated strings
            // const seconds: u32 = @intFromFloat(ray.GetTime());
            // const dynamic = try std.fmt.allocPrintZ(allocator, "running since {d} seconds", .{seconds});
            // defer allocator.free(dynamic);
            // ray.DrawText(dynamic, 300, 250, 20, ray.WHITE);

            ray.DrawFPS(width - 100, 10);
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
