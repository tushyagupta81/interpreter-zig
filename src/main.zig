const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    var args = std.process.args();
    _ = args.next().?;
    if (args.next()) |arg| {
        print("This is a file mode, file = {s}\n", .{arg});
        const file = try std.fs.cwd().openFile(arg, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            print("{s}\n", .{line});
        }
    } else {
        print("repl mode", .{});
    }
}
