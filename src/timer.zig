const std = @import("std");

var exit = false;

fn signalHandler(sig: std.posix.SIG) callconv(.c) void {
    switch (sig) {
        .INT => exit = true,
        .TERM => exit = true,
        else => {},
    }
}

pub fn main() !void {
    const sigset_t: std.posix.sigset_t = std.mem.zeroes(std.posix.sigset_t);
    const sig_action = std.posix.Sigaction{ .handler = .{ .handler = signalHandler }, .mask = sigset_t, .flags = 0 };
    std.posix.sigaction(.INT, &sig_action, null);
    std.posix.sigaction(.TERM, &sig_action, null);

    var io_bullshit = std.Io.Threaded.init_single_threaded;
    const io = io_bullshit.io();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_writer = std.Io.File.stderr().writer(io, &.{});
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    const start_mode = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
    defer std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, start_mode) catch {
        stderr.writeAll("Sowwy for scwewing up the tewminal\r\nType reset to get it back to nowmal\r\n") catch {};
    };
    var new_mode = start_mode;

    // what cfmakeraw() does from termios.h
    new_mode.iflag.IGNBRK = false;
    new_mode.iflag.BRKINT = false;
    new_mode.iflag.PARMRK = false;
    new_mode.iflag.ISTRIP = false;
    new_mode.iflag.INLCR = false;
    new_mode.iflag.IGNCR = false;
    new_mode.iflag.ICRNL = false;
    new_mode.iflag.IXON = false;
    new_mode.oflag.OPOST = false;
    new_mode.lflag.ECHO = false;
    new_mode.lflag.ECHONL = false;
    new_mode.lflag.ICANON = false;
    new_mode.lflag.ISIG = true;
    new_mode.lflag.IEXTEN = false;
    new_mode.cflag.CSIZE = .CS8;
    new_mode.cflag.PARENB = false;

    // Set timeout for read systemcall
    new_mode.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    new_mode.cc[@intFromEnum(std.posix.V.TIME)] = 0;

    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, new_mode);

    try stdout.writeAll("Press \"q\" to exit\r\n");
    defer stdout.writeAll(&[_]u8{ 0x1B, 'M', 0x1B, '[', '2', 'K' }) catch {};

    var clock = std.Io.Clock.boot;
    const start_time = clock.now(io);
    var frame_start_time = start_time;
    while (!exit) {
        while (true) {
            var input_buf: [256]u8 = undefined;
            const bytes_read = try stdin.readSliceShort(&input_buf);
            for (input_buf[0..bytes_read]) |char| {
                if (char == 'q' or char == 'Q') {
                    exit = true;
                }
            }
            if (bytes_read < stdin_buf.len) break;
        }
        const passed_time = start_time.untilNow(io, clock);
        {
            // The theoretical maximum amount of bytes the hours can take up is 26 bytes
            // The length of the string minus the length of the hours is 14
            var out_buf: [14 + 26]u8 = undefined;
            const print_buf = std.fmt.bufPrint(&out_buf, "Time: {d}:{d:02}:{d:02}\r\n", .{
                @as(u96, @intCast(@abs(@divTrunc(passed_time.nanoseconds, std.time.ns_per_hour)))),
                @as(u96, @intCast(@abs(@mod(@divTrunc(passed_time.nanoseconds, std.time.ns_per_min), 60)))),
                @as(u96, @intCast(@abs(@mod(@divTrunc(passed_time.nanoseconds, std.time.ns_per_s), 60)))),
            }) catch unreachable;
            try stdout.writeAll(print_buf);
        }
        // Flush output before sleeping
        try stdout.flush();
        const frame_passed_time = frame_start_time.untilNow(io, clock);
        if (frame_passed_time.nanoseconds < std.time.ns_per_ms * 10 and frame_passed_time.nanoseconds >= 0) {
            try std.Io.sleep(io, std.Io.Duration.fromNanoseconds(std.time.ns_per_ms * 10 - frame_passed_time.nanoseconds), clock);
        }
        try stdout.writeAll(&[_]u8{ 0x1B, 'M', 0x1B, '[', '2', 'K' });
        frame_start_time = clock.now(io);
    }
}
