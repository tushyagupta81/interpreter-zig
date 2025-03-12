const std = @import("std");
const LiteralValue = @import("./token.zig").LiteralValue;
const Interpreter = @import("./interpreter.zig").Interpreter;
const Stmt = @import("./statement.zig").Stmt;
const Environment = @import("./environment.zig").Environment;

pub fn clock(_: *Stmt, _: *Interpreter, _: std.ArrayList(LiteralValue), _: *Environment) anyerror!LiteralValue {
    const time = std.time.timestamp();
    const obj = LiteralValue{ .Float = @floatFromInt(time) };

    return obj;
}
