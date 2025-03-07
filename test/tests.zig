const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;

fn test_template(test_file: []const u8, exit_code: u8, expected_output: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const argv = [_][]const u8{
        "./zig-out/bin/interpreter-zig",
        test_file,
    };

    // By default, child will inherit stdout & stderr from its parents,
    // this usually means that child's output will be printed to terminal.
    // Here we change them to pipe and collect into `ArrayList`.
    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var stdout: std.ArrayListUnmanaged(u8) = .empty;
    var stderr: std.ArrayListUnmanaged(u8) = .empty;

    try child.spawn();
    try child.collectOutput(allocator, &stdout, &stderr, 1024);
    const term = try child.wait();

    try std.testing.expectEqual(term.Exited, exit_code);
    try std.testing.expectEqualStrings(expected_output, stdout.items);
    try std.testing.expectEqualStrings("", stderr.items);
}

test "build exe" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const argv = [_][]const u8{
        "zig",
        "build",
    };

    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var stdout: std.ArrayListUnmanaged(u8) = .empty;
    var stderr: std.ArrayListUnmanaged(u8) = .empty;

    try child.spawn();
    try child.collectOutput(allocator, &stdout, &stderr, 1024);
    const term = try child.wait();

    try std.testing.expectEqual(term.Exited, 0);
    try std.testing.expectEqualStrings("", stdout.items);
    try std.testing.expectEqualStrings("", stderr.items);
}

test "maths" {
    try test_template("./test/maths.tox", 0,
        \\2
        \\80
        \\25
        \\47
        \\
    );
}

test "while loop" {
    try test_template("./test/while.tox", 0,
        \\0
        \\1
        \\2
        \\3
        \\4
        \\5
        \\6
        \\7
        \\8
        \\9
        \\
    );
}

test "for loop" {
    try test_template("./test/for.tox", 0,
        \\0
        \\1
        \\1
        \\2
        \\3
        \\5
        \\8
        \\13
        \\21
        \\34
        \\55
        \\89
        \\144
        \\233
        \\377
        \\610
        \\987
        \\1597
        \\2584
        \\4181
        \\6765
        \\
    );
}

test "function" {
    try test_template("./test/function.tox", 0,
        \\Hello Tushya
        \\
    );
}
