const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const Scanner = @import("./scanner.zig").Scanner;

pub var has_err: bool = false;

pub fn base_error(line: u32, msg: []const u8) !void {
    try report(line, "", msg);
}

pub fn report(line: u32, where: []u8, msg: []const u8) !void {
    try stdout.print("[line {}] Error {s}: {s}\n", .{ line, where, msg });
    has_err = true;
}

fn run(source: []u8, allocator: std.mem.Allocator) !void {
    var scanner = Scanner.init(allocator, source);
    defer scanner.deinit();
    const tokens = try scanner.scan_tokens();
    for (tokens.items) |tk| {
        const token_to_string = try tk.to_string(allocator);
        defer allocator.free(token_to_string);
        try stdout.print("{s}", .{token_to_string});
    }
    // if (has_err) {
    //     std.process.exit(64);
    // }
}

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

    try run(contents, allocator);
}

fn run_promt(allocator: std.mem.Allocator) !void {
    try stdout.print("repl mode\n", .{});
    while (true) {
        try stdout.print("\n> ", .{});

        const line = (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize))) orelse break;
        defer allocator.free(line);

        try run(line, allocator);

        if (std.mem.eql(u8, line, "") or std.mem.eql(u8, line, "exit")) break;
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
