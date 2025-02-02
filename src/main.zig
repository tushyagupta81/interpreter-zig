const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

fn run_file(allocator: std.mem.Allocator, file_path: []const u8) !void {
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        if (err == std.fs.File.OpenError.FileNotFound) {
            try stdout.print("File not found!\n", .{});
            std.process.exit(64);
        } else {
            try stdout.print("Error: {any}\n", .{err});
            std.process.exit(64);
        }
    };
    defer file.close();

    const file_size = (try file.stat()).size;
    const contents = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(contents);

    try stdout.print("{s}", .{contents});
}

fn run_promt(allocator: std.mem.Allocator) !void {
    try stdout.print("repl mode\n", .{});
    while (true) {
        try stdout.print("> ", .{});
        const line = (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize))) orelse "";
        defer allocator.free(line);
        if (std.mem.eql(u8, line, "") or std.mem.eql(u8, line, "exit")) {
            try stdout.print("\nExiting program\n", .{});
            break;
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 2) {
        try stdout.print("Usage: tox <file_path>", .{});
        std.process.exit(64);
    } else if (args.len == 2) {
        try run_file(allocator, args[1]);
    } else {
        try run_promt(allocator);
    }
}
