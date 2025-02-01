const std = @import("std");
const stdout = std.io.getStdOut().writer();

fn run_file(file_path: []const u8) !void {
    try stdout.print("This is a file mode, file = {s}\n", .{file_path});

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

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try stdout.print("{s}\n", .{line});
    }
}

fn run_promt() !void {
    try stdout.print("repl mode\n", .{});
}

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer gpa.deinit();
    // const allocator = gpa.allocator();
    var args = std.process.args();
    if (args.inner.count > 3) {
        try stdout.print("Usage: tox <file_path>", .{});
        std.process.exit(64);
    }
    _ = args.next().?;
    if (args.next()) |arg| {
        try run_file(arg);
    } else {
        try run_promt();
    }
}
