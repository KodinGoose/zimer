const std = @import("std");

pub fn main() !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buf: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
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
    new_mode.lflag.ISIG = false;
    new_mode.lflag.IEXTEN = false;
    new_mode.cflag.CSIZE = .CS8;
    new_mode.cflag.PARENB = false;

    // Set timeout for read systemcall
    new_mode.cc[@intFromEnum(std.posix.V.MIN)] = 0;
    new_mode.cc[@intFromEnum(std.posix.V.TIME)] = 0;

    try stdout.writeAll("Press \"q\" to exit\r\n");
    defer stdout.writeAll(&[_]u8{ 0x1B, 'M', 0x1B, '[', '2', 'K' }) catch {};

    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, new_mode);

    const start_nanotime = std.time.nanoTimestamp();
    var frame_start_time = start_nanotime;
    var exit = false;
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
        const passed_nanotime = std.time.nanoTimestamp() - start_nanotime;
        {
            // The theoretical maximum amount of bytes the hours can take up is 26 bytes
            // The length of the string minus the length of the hours is 14
            var out_buf: [14 + 26]u8 = undefined;
            const print_buf = std.fmt.bufPrint(&out_buf, "Time: {d}:{d:02}:{d:02}\r\n", .{
                @as(u128, @intCast(@abs(@divTrunc(passed_nanotime, std.time.ns_per_hour)))),
                @as(u128, @intCast(@abs(@mod(@divTrunc(passed_nanotime, std.time.ns_per_min), 60)))),
                @as(u128, @intCast(@abs(@mod(@divTrunc(passed_nanotime, std.time.ns_per_s), 60)))),
            }) catch unreachable;
            try stdout.writeAll(print_buf);
        }
        // Flush output before sleeping
        try stdout.flush();
        // This division never results in a negative number unless the user sets the system clock back
        const frame_passed_time = std.time.nanoTimestamp() -% frame_start_time;
        if (frame_passed_time < std.time.ns_per_ms * 10 and frame_passed_time >= 0) {
            std.Thread.sleep(std.time.ns_per_ms * 10 - @as(u64, @intCast(frame_passed_time)));
        }
        try stdout.writeAll(&[_]u8{ 0x1B, 'M', 0x1B, '[', '2', 'K' });
        frame_start_time = std.time.nanoTimestamp();
    }
}
