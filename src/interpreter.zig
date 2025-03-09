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
const std_lib = @import("./std_lib.zig");

const InterpreterError = error{
    ExpectedLeft,
    ExpectedRight,
    ArgumentMismatch,
    NotACallable,
};

pub const Interpreter = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    environment: Environment,
    specials: Environment,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var globals = Environment.init(allocator);
        const clock_callable = LiteralValue{
            .Callable = .{
                .arity = 0,
                .call = std_lib.clock,
                .stmt = undefined,
            },
        };
        try globals.define(Token{
            .line = 0,
            .lexeme = "clock",
            .literal = null,
            .type = TokenType.Fun,
        }, clock_callable);
        return Self{
            .allocator = allocator,
            .environment = globals,
            .specials = Environment.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.environment.deinit();
        self.specials.deinit();
    }

    pub fn evaluvate_stmts(self: *Self, stmts: std.ArrayList(*Stmt)) !void {
        for (stmts.items) |stmt| {
            self.evaluvate_stmt(stmt) catch |err| {
                switch (err) {
                    InterpreterError.ExpectedLeft => try runtime_error(0, "Expected Left Argument."),
                    InterpreterError.ExpectedRight => try runtime_error(0, "Expected Right Argument."),
                    InterpreterError.ArgumentMismatch => try runtime_error(0, "Argument Mismatch"),
                    InterpreterError.NotACallable => try runtime_error(0, "Not a Callable"),
                    else => return err,
                }
            };
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
            Stmt.block_stmt => {
                var previous = self.environment;
                self.environment = Environment.init(self.allocator);
                self.environment.enclosing = &previous;
                for (stmt.block_stmt.stmts) |st| {
                    try self.evaluvate_stmt(st);
                }
                self.environment.deinit();
                self.environment = previous;
            },
            Stmt.if_stmt => {
                const lit = try self.evaluvate(stmt.if_stmt.condition);
                if (lit) |l| {
                    if (self.is_truthy(l)) {
                        try self.evaluvate_stmt(stmt.if_stmt.then_branch);
                    } else if (stmt.if_stmt.else_branch) |else_b| {
                        try self.evaluvate_stmt(else_b);
                    }
                }
            },
            Stmt.while_stmt => {
                while (true) {
                    const lit = try self.evaluvate(stmt.while_stmt.condition);
                    if (lit) |l| {
                        if (!self.is_truthy(l)) {
                            break;
                        }
                    } else {
                        break;
                    }
                    try self.evaluvate_stmt(stmt.while_stmt.body);
                }
            },
            Stmt.funcStmt => {
                const fun = struct {
                    fn call(stmt_: *Stmt, inter: *Interpreter, args: std.ArrayList(LiteralValue)) anyerror!LiteralValue {
                        var parenEnv = inter.environment;
                        defer inter.environment = parenEnv;
                        inter.environment = Environment.init(inter.allocator);
                        inter.environment.enclosing = &parenEnv;
                        defer inter.environment.deinit();

                        for (0..args.items.len) |i| {
                            try inter.environment.define(stmt_.funcStmt.params.items[i], args.items[i]);
                        }

                        for (stmt_.funcStmt.body) |s| {
                            try inter.evaluvate_stmt(s);
                            if (try inter.specials.get_no_warn(Token{
                                .lexeme = "return",
                                .line = 0,
                                .literal = null,
                                .type = TokenType.Return,
                            })) |r| {
                                defer _ = inter.specials.values.remove("return");
                                return r;
                            }
                        }

                        return LiteralValue{ .Nil = {} };
                    }
                }.call;

                const callable = LiteralValue{
                    .Callable = .{
                        .arity = stmt.funcStmt.params.items.len,
                        .call = fun,
                        .stmt = stmt,
                    },
                };

                try self.environment.define(stmt.funcStmt.name, callable);
            },
            Stmt.return_stmt => {
                var value: LiteralValue = undefined;
                if (stmt.return_stmt.value) |v| {
                    value = (try self.evaluvate(v)).?;
                } else {
                    value = LiteralValue{
                        .Nil = {},
                    };
                }
                try self.specials.define(Token{
                    .lexeme = "return",
                    .line = stmt.return_stmt.keyword.line,
                    .literal = stmt.return_stmt.keyword.literal,
                    .type = TokenType.Return,
                }, value);
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
            Expr.logical => {
                return try self.evaluvate_logical(&expr.logical);
            },
            Expr.callExpr => {
                return try self.evaluvate_call(&expr.callExpr);
            },
        }
        return null;
    }

    fn evaluvate_call(self: *Self, expr: *ExprType.callExpr) anyerror!?LiteralValue {
        const callee = (try self.evaluvate(expr.callee)).?;

        var args = std.ArrayList(LiteralValue).init(self.allocator);
        defer args.deinit();

        for (expr.arguments.items) |arg| {
            try args.append((try self.evaluvate(arg)).?);
        }

        if (callee != LiteralValue.Callable) {
            try runtime_error(expr.paren.line, "Can only call funcitons and classes");
            return InterpreterError.ArgumentMismatch;
        }

        if (args.items.len != callee.Callable.arity) {
            const err = try std.fmt.allocPrint(self.allocator, "Expected {} arguments but got {}", .{ expr.arguments.items.len, args.items.len });
            defer self.allocator.free(err);
            try runtime_error(expr.paren.line, err);
            return InterpreterError.NotACallable;
        }

        const func = callee.Callable.call;

        return try func(callee.Callable.stmt, self, args);
    }

    fn evaluvate_logical(self: *Self, expr: *ExprType.LogicalExpr) anyerror!?LiteralValue {
        const left = (try self.evaluvate(expr.left)).?;

        if (expr.op.type == TokenType.Or) {
            if (self.is_truthy(left)) return left;
        } else {
            if (!self.is_truthy(left)) return left;
        }

        return try self.evaluvate(expr.right);
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
            LiteralValue.Callable => return true,
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
