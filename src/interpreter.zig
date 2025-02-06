const std = @import("std");
const Expr = @import("./expr.zig").Expr;
const ExprType = @import("./expr.zig");
const TokenType = @import("./token.zig").TokenType;
const LiteralValue = @import("./token.zig").LiteralValue;
const base_error = @import("./main.zig").base_error;

const InterpreterError = error{
    ExpectedLeft,
    ExpectedRight,
};

pub const Interpreter = struct {
    const Self = @This();
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn evaluvate(self: *Self, expr: *Expr) !?LiteralValue {
        switch (expr.*) {
            Expr.unary => {
                return try self.evaluvate_unary(&expr.unary);
            },
            Expr.binary => {
                return try self.evaluvate_binary(&expr.binary);
            },
            Expr.grouping => {
                std.debug.print("Grouping", .{});
                // return try self.evaluvate_binary(&grouping);
            },
            Expr.literal => {
                std.debug.print("Literal", .{});
                // return try self.evaluvate_binary(&literal);
            },
        }
        return null;
    }

    fn evaluvate_binary(self: *Self, expr: *ExprType.BinaryExpr) anyerror!LiteralValue {
        std.debug.print("Hello world {any}", .{@TypeOf(expr.*)});
        const left = try self.evaluvate(expr.left) orelse return InterpreterError.ExpectedLeft;
        const right = try self.evaluvate(expr.right) orelse return InterpreterError.ExpectedRight;

        if (@intFromEnum(left) == @intFromEnum(LiteralValue.Float) and @intFromEnum(right) == @intFromEnum(LiteralValue.Float)) {
            switch (expr.op.type) {
                TokenType.Plus => {
                    return LiteralValue{ .Float = left.Float + right.Float };
                },
                TokenType.Minus => {
                    return LiteralValue{ .Float = left.Float - right.Float };
                },
                TokenType.Slash => {
                    return LiteralValue{ .Float = left.Float / right.Float };
                },
                TokenType.Star => {
                    return LiteralValue{ .Float = left.Float * right.Float };
                },
                TokenType.Greater => {
                    return LiteralValue{ .Bool = left.Float > right.Float };
                },
                TokenType.Less => {
                    return LiteralValue{ .Bool = left.Float < right.Float };
                },
                TokenType.Greater_equal => {
                    return LiteralValue{ .Bool = left.Float >= right.Float };
                },
                TokenType.Less_equal => {
                    return LiteralValue{ .Bool = left.Float <= right.Float };
                },
                else => try base_error(expr.op.line, "Unexpected character in binary expression"),
            }
        } else if (@intFromEnum(left) == @intFromEnum(LiteralValue.String) and @intFromEnum(right) == @intFromEnum(LiteralValue.String)) {
            switch (expr.op.type) {
                TokenType.Plus => {
                    var buf: [4096]u8 = undefined;
                    return LiteralValue{ .String = try std.fmt.bufPrint(&buf, "{s}{s}", .{ left.String, right.String }) };
                },
                else => try base_error(expr.op.line, "Unexpected character in binary expression"),
            }
        }

        unreachable;
    }

    fn evaluvate_unary(self: *Self, expr: *const ExprType.UnaryExpr) anyerror!LiteralValue {
        const right = try self.evaluvate(expr.right) orelse return InterpreterError.ExpectedRight;

        switch (expr.op.type) {
            TokenType.Minus => {
                return right;
            },
            TokenType.Bang => {
                return LiteralValue{ .Bool = !self.isTruthy(right) };
            },
            else => try base_error(expr.op.line, "Unexpected charecter"),
        }

        unreachable;
    }

    fn isTruthy(_: *Self, val: LiteralValue) bool {
        switch (val) {
            LiteralValue.Bool => |b| return b,
            LiteralValue.Nil => return false,
            LiteralValue.Float => |f| {
                if (f == 0) {
                    return false;
                } else {
                    return true;
                }
            },
            LiteralValue.String => return true,
        }
    }
};
