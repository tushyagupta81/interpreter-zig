const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;

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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const argv = [_][]const u8{
        "./zig-out/bin/interpreter-zig",
        "./test/maths.tox",
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

    try std.testing.expectEqual(term.Exited, 0);
    try std.testing.expectEqualStrings(
        \\2
        \\80
        \\25
        \\47
        \\
    , stdout.items);
    try std.testing.expectEqualStrings("", stderr.items);
}
