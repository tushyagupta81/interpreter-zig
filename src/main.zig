const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

const Scanner = @import("./scanner.zig").Scanner;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const Parser = @import("./parser.zig").Parser;
const ExprType = @import("./expr.zig");
const to_string = @import("./expr.zig").to_string;
const LiteralValue = @import("./token.zig").LiteralValue;

pub var has_err: bool = false;

pub fn base_error(line: u32, msg: []const u8) !void {
    try report(line, "", msg);
}

pub fn parse_error(token: Token, msg: []const u8, allocator: std.mem.Allocator) !void {
    if (token.type == TokenType.Eof) {
        const buf = try std.fmt.allocPrint(allocator, "at end", .{});
        try report(token.line, buf, msg);
    } else {
        const buf = try std.fmt.allocPrint(allocator, "at '{s}'", .{token.lexeme});
        try report(token.line, buf, msg);
    }
}

pub fn report(line: u32, where: []u8, msg: []const u8) !void {
    try stdout.print("[line {}] Error {s}: {s}\n", .{ line, where, msg });
    has_err = true;
}

fn run(source: []u8, allocator: std.mem.Allocator) !void {
    var scanner = Scanner.init(allocator, source);
    defer scanner.deinit();
    const tokens = try scanner.scan_tokens();
    // for (tokens.items) |tk| {
    //     const token_to_string = try tk.to_string(allocator);
    //     defer allocator.free(token_to_string);
    //     try stdout.print("{s}", .{token_to_string});
    // }
    // try stdout.print("\n\n\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arenaAlloc = arena.allocator();

    var parser = Parser.init(arenaAlloc, tokens);

    const exprs = try parser.parse();
    defer exprs.deinit();

    for (exprs.items) |expr| {
        const res = try expr.to_string(@constCast(&arenaAlloc));
        try stdout.print("{s}\n", .{res});
    }
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

        if (std.mem.eql(u8, line, "") or std.mem.eql(u8, line, "exit")) break;

        try run(line, allocator);
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
