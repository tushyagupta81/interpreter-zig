const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Expr = @import("./expr.zig").Expr;
const Stmt = @import("./statement.zig").Stmt;
const ExprType = @import("./expr.zig");
const TokenType = @import("./token.zig").TokenType;
const Token = @import("./token.zig").Token;
const LiteralValue = @import("./token.zig").LiteralValue;
const runtime_error = @import("./main.zig").runtime_error;
const Environment = @import("./environment.zig").Environment;

const InterpreterError = error{
    ExpectedLeft,
    ExpectedRight,
};

pub const Interpreter = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    environment: Environment,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .environment = Environment.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.environment.deinit();
    }

    pub fn evaluvate_stmts(self: *Self, stmts: std.ArrayList(*Stmt)) !void {
        for (stmts.items) |stmt| {
            try self.evaluvate_stmt(stmt);
        }
    }

    fn evaluvate_stmt(self: *Self, stmt: *Stmt) !void {
        switch (stmt.*) {
            Stmt.expr_stmt => {
                _ = try self.evaluvate(stmt.expr_stmt.expr);
            },
            Stmt.print_stmt => {
                const lit = try self.evaluvate(stmt.print_stmt.expr);
                if (lit) |l| {
                    try stdout.print("{s}\n", .{try l.to_string()});
                }
            },
            Stmt.var_stmt => {
                var value: LiteralValue = undefined;
                if (stmt.var_stmt.initializer) |initializer| {
                    if (try self.evaluvate(initializer)) |v| {
                        value = v;
                    } else {
                        value = LiteralValue{
                            .Nil = {},
                        };
                    }
                } else {
                    value = LiteralValue{
                        .Nil = {},
                    };
                }

                try self.environment.define(stmt.var_stmt.name, value);
            },
            // else => {},
        }
    }

    fn evaluvate(self: *Self, expr: *Expr) !?LiteralValue {
        switch (expr.*) {
            Expr.unary => {
                return try self.evaluvate_unary(&expr.unary);
            },
            Expr.binary => {
                return try self.evaluvate_binary(&expr.binary);
            },
            Expr.grouping => {
                return try self.evaluvate(expr.grouping.expression);
                // return try self.evaluvate_binary(&grouping);
            },
            Expr.literal => {
                return expr.literal.value;
                // return try self.evaluvate_binary(&literal);
            },
            Expr.variable => {
                return try self.evaluvate_variable(expr.variable.name);
            },
            Expr.assign => {
                return try self.evaluvate_assign(&expr.assign);
            },
        }
        return null;
    }

    fn evaluvate_assign(self: *Self, expr: *ExprType.AssignExpr) anyerror!?LiteralValue {
        const val = try self.evaluvate(expr.value) orelse return null;
        try self.environment.assign(expr.name, val);
        return val;
    }

    fn evaluvate_variable(self: *Self, name: Token) !?LiteralValue {
        return try self.environment.get(name);
    }

    fn evaluvate_binary(self: *Self, expr: *ExprType.BinaryExpr) anyerror!?LiteralValue {
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
                    if (right.Float == 0) {
                        try runtime_error(expr.op.line, "Divide by 0");
                        return null;
                    }
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
                TokenType.Equal_equal => {
                    return LiteralValue{ .Bool = self.is_equal(left, right) };
                },
                TokenType.Bang_equal => {
                    return LiteralValue{ .Bool = !self.is_equal(left, right) };
                },
                else => try runtime_error(expr.op.line, "Unexpected character in binary expression"),
            }
        } else if (@intFromEnum(left) == @intFromEnum(LiteralValue.String) and @intFromEnum(right) == @intFromEnum(LiteralValue.String)) {
            switch (expr.op.type) {
                TokenType.Plus => {
                    var buf: [4096]u8 = undefined;
                    return LiteralValue{ .String = try std.fmt.bufPrint(&buf, "{s}{s}", .{ left.String, right.String }) };
                },
                else => try runtime_error(expr.op.line, "Unexpected character in binary expression"),
            }
        } else if (@intFromEnum(left) == @intFromEnum(LiteralValue.String) and @intFromEnum(right) == @intFromEnum(LiteralValue.Float)) {
            switch (expr.op.type) {
                TokenType.Plus => {
                    var buf: [4096]u8 = undefined;
                    return LiteralValue{ .String = try std.fmt.bufPrint(&buf, "{s}{d}", .{ left.String, right.Float }) };
                },
                else => try runtime_error(expr.op.line, "Unexpected character in binary expression"),
            }
        } else {
            try runtime_error(expr.op.line, "Cannot preform binary action on diffrent data types");
            return null;
        }

        unreachable;
    }

    fn evaluvate_unary(self: *Self, expr: *const ExprType.UnaryExpr) anyerror!?LiteralValue {
        const right = try self.evaluvate(expr.right) orelse return InterpreterError.ExpectedRight;

        switch (expr.op.type) {
            TokenType.Minus => {
                return right;
            },
            TokenType.Bang => {
                return LiteralValue{ .Bool = !self.is_truthy(right) };
            },
            else => {
                try runtime_error(expr.op.line, "Unexpected character");
                return null;
            },
        }

        unreachable;
    }

    fn is_truthy(_: *Self, val: LiteralValue) bool {
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

    fn is_equal(_: *Self, left: LiteralValue, right: LiteralValue) bool {
        if (@intFromEnum(left) == @intFromEnum(right)) {
            if (left == LiteralValue.Float) {
                return left.Float == right.Float;
            } else if (left == LiteralValue.String) {
                return std.mem.eql(u8, left.String, right.String);
            } else if (left == LiteralValue.Bool) {
                return left.Bool == right.Bool;
            } else {
                return true;
            }
        }
        return false;
    }
};
