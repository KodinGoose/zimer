const std = @import("std");

pub fn main() !void {
    const start_mode = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
    defer std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, start_mode) catch {
        std.io.getStdErr().writeAll("Sowwy for scwewing up the tewminal\r\nType reset to get it back to nowmal\r\n") catch {};
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

    var input_buffer = try std.heap.page_allocator.alloc(u8, 256);
    defer std.heap.page_allocator.free(input_buffer);

    const help_text = "Press \"q\" to exit\r\n";
    try std.io.getStdOut().writer().writeAll(help_text);
    defer std.io.getStdOut().writer().writeAll([_]u8{ 0x1B, 'M' } ++ &[_]u8{0x08} ** help_text.len) catch {};

    try std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, new_mode);

    const start_nanotime = std.time.nanoTimestamp();
    var last_output_len: usize = 0;
    var exit = false;
    while (!exit) {
        const frame_start_time = std.time.nanoTimestamp();
        const bytes_read = try std.io.getStdIn().reader().read(input_buffer);
        for (input_buffer[0..bytes_read]) |char| {
            if (char == 'q' or char == 'Q') {
                exit = true;
            }
        }
        const nanotime = std.time.nanoTimestamp();
        const passed_nanotime = nanotime - start_nanotime;
        {
            const print_buf = try std.fmt.allocPrint(std.heap.page_allocator, "Time: {d}:{d:02}:{d:02}\r\n", .{
                @as(u128, @intCast(@abs(@divTrunc(passed_nanotime, std.time.ns_per_hour)))),
                @as(u128, @intCast(@abs(@mod(@divTrunc(passed_nanotime, std.time.ns_per_min), 60)))),
                @as(u128, @intCast(@abs(@mod(@divTrunc(passed_nanotime, std.time.ns_per_s), 60)))),
            });
            defer std.heap.page_allocator.free(print_buf);
            last_output_len = print_buf.len;
            try std.io.getStdOut().writer().writeAll(print_buf);
        }
        const frame_passed_time = std.time.nanoTimestamp() - frame_start_time;
        if (frame_passed_time < std.time.ns_per_ms * 10 and frame_passed_time >= 0) {
            std.Thread.sleep(std.time.ns_per_ms * 10 - @as(u64, @intCast(frame_passed_time)));
        }
        {
            const print_buf = try std.heap.page_allocator.alloc(u8, last_output_len);
            defer std.heap.page_allocator.free(print_buf);
            for (print_buf) |*char| {
                char.* = 0x08;
            }
            try std.io.getStdOut().writer().writeAll(&[_]u8{ 0x1B, 'M' });
            try std.io.getStdOut().writer().writeAll(print_buf);
        }
    }
}
