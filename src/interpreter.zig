const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Expr = @import("./expr.zig").Expr;
const ExprIntHashMap = @import("./expr.zig").ExprIntHashMap;
const Stmt = @import("./statement.zig").Stmt;
const ClassInstance = @import("./token.zig").ClassInstance;
const ExprType = @import("./expr.zig");
const TokenType = @import("./token.zig").TokenType;
const Token = @import("./token.zig").Token;
const LiteralValue = @import("./token.zig").LiteralValue;
const runtime_error = @import("./main.zig").runtime_error;
const Environment = @import("./environment.zig").Environment;
const std_lib = @import("./std_lib.zig");

pub const InterpreterError = error{
    ExpectedLeft,
    ExpectedRight,
    ArgumentMismatch,
    NotACallable,
    NotAInstance,
    UndefinedProperty,
};

pub const Interpreter = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    environment: *Environment,
    globals: *Environment,
    specials: *Environment,
    to_free: std.ArrayList(*Environment),
    to_free2: std.ArrayList(std.ArrayList(u8)),
    to_free3: std.ArrayList(*ClassInstance),
    // locals: std.ArrayHashMap(Expr, i32, ExprContext, true),
    // locals: std.StringHashMap(i32),
    locals: ExprIntHashMap,

    pub fn init(allocator: std.mem.Allocator) !Self {
        const globals = try allocator.create(Environment);
        globals.* = Environment.init(allocator);
        const clock_callable = LiteralValue{
            .Callable = .{
                .name = "clock",
                .arity = 0,
                .call = std_lib.clock,
                .stmt = undefined,
                .env = undefined,
            },
        };
        try globals.define(Token{
            .line = 0,
            .lexeme = "clock",
            .literal = null,
            .type = TokenType.Fun,
        }, clock_callable);

        const specials = try allocator.create(Environment);
        specials.* = Environment.init(allocator);

        return Self{
            .allocator = allocator,
            .environment = globals,
            .globals = globals,
            .specials = specials,
            .to_free = std.ArrayList(*Environment).init(allocator),
            .to_free2 = std.ArrayList(std.ArrayList(u8)).init(allocator),
            .to_free3 = std.ArrayList(*ClassInstance).init(allocator),
            .locals = ExprIntHashMap.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.environment.deinit();
        self.allocator.destroy(self.environment);
        self.specials.deinit();
        self.allocator.destroy(self.specials);
        for (self.to_free.items) |item| {
            item.deinit();
            self.allocator.destroy(item);
        }
        self.to_free.deinit();

        for (self.to_free2.items) |item| {
            item.deinit();
        }
        self.to_free2.deinit();

        for (self.to_free3.items) |item| {
            item.deinit();
        }
        self.to_free3.deinit();

        self.locals.deinit();
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
                const previous = self.environment;
                const env = try self.allocator.create(Environment);
                env.* = Environment.init(self.allocator);
                try self.to_free.append(env);
                self.environment = env;
                self.environment.enclosing = previous;
                for (stmt.block_stmt.stmts) |st| {
                    try self.evaluvate_stmt(st);
                }
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
            Stmt.func_stmt => {
                const fun = struct {
                    fn call(stmt_: *Stmt, inter: *Interpreter, args: std.ArrayList(LiteralValue), parent: *Environment) anyerror!LiteralValue {
                        const parenEnv = inter.environment;
                        defer inter.environment = parenEnv;
                        const env = try inter.allocator.create(Environment);
                        env.* = Environment.init(inter.allocator);
                        try inter.to_free.append(env);
                        inter.environment = env;
                        inter.environment.enclosing = parent;

                        for (0..args.items.len) |i| {
                            try inter.environment.define(stmt_.func_stmt.params.items[i], args.items[i]);
                        }

                        for (stmt_.func_stmt.body) |s| {
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

                // Able to do the work of the resolver(not full tho) :)
                // const env = try self.allocator.create(Environment);
                // env.* = self.environment.*;
                // try self.to_free.append(env);

                const callable = LiteralValue{
                    .Callable = .{
                        .name = stmt.func_stmt.name.lexeme,
                        .arity = stmt.func_stmt.params.items.len,
                        .call = fun,
                        .stmt = stmt,
                        .env = self.environment,
                        // .env = env,
                    },
                };

                try self.environment.define(stmt.func_stmt.name, callable);
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
            Stmt.class_stmt => {
                try self.environment.define(stmt.class_stmt.name, LiteralValue{ .Nil = {} });

                var methods = std.StringHashMap(*Stmt).init(self.allocator);

                for(stmt.class_stmt.methods) |method| {
                }

                const class = LiteralValue{
                    .Class = .{
                        .name = &stmt.class_stmt.name,
                    },
                };

                try self.environment.assign(stmt.class_stmt.name, class);
            },
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
                // return try self.evaluvate_variable(expr.variable.name);
                return try self.look_up_variable(expr.variable.name, expr);
            },
            Expr.assign => {
                return try self.evaluvate_assign(expr);
            },
            Expr.logical => {
                return try self.evaluvate_logical(&expr.logical);
            },
            Expr.callExpr => {
                return try self.evaluvate_call(&expr.callExpr);
            },
            Expr.getExpr => {
                return try self.evaluvate_get(&expr.getExpr);
            },
            Expr.setExpr => {
                return try self.evaluvate_set(&expr.setExpr);
            },
        }
        return null;
    }

    fn evaluvate_set(self: *Self, expr: *ExprType.SetExpr) anyerror!?LiteralValue {
        var obj = (try self.evaluvate(expr.object)).?;

        if (obj != LiteralValue.ClassInstance) {
            try runtime_error(expr.name.line, "Only instances have fields");
            return InterpreterError.NotAInstance;
        }

        const value = (try self.evaluvate(expr.value)).?;
        try obj.ClassInstance.set(expr.name, value);

        return value;
    }

    fn evaluvate_get(self: *Self, expr: *ExprType.GetExpr) anyerror!?LiteralValue {
        var obj = try self.evaluvate(expr.object);
        if (obj) |_| {
            if (obj.? == LiteralValue.ClassInstance) {
                return try obj.?.ClassInstance.get(expr.name);
            }
        }

        return InterpreterError.NotACallable;
    }

    fn look_up_variable(self: *Self, name: Token, expr: *Expr) anyerror!?LiteralValue {
        // var res = std.ArrayList(u8).init(self.allocator);
        // try expr.to_string(&res);
        // try self.to_free2.append(res);
        const distance = self.locals.get(expr);
        // var it = self.locals.iterator();
        // while (it.next()) |v| {
        //     std.debug.print("{any}\n", .{v.value_ptr.*});
        // }
        if (distance) |d| {
            return self.environment.get_at(d, name);
        } else {
            return self.globals.get(name);
        }
    }

    fn evaluvate_call(self: *Self, expr: *ExprType.callExpr) anyerror!?LiteralValue {
        const callee = (try self.evaluvate(expr.callee)).?;

        var args = std.ArrayList(LiteralValue).init(self.allocator);
        defer args.deinit();

        for (expr.arguments.items) |arg| {
            try args.append((try self.evaluvate(arg)).?);
        }

        // if (!(callee == LiteralValue.Callable or callee == LiteralValue.Class)) {
        // }

        if (callee == LiteralValue.Callable) {
            if (args.items.len != callee.Callable.arity) {
                const err = try std.fmt.allocPrint(self.allocator, "Expected {} arguments but got {}", .{ expr.arguments.items.len, args.items.len });
                defer self.allocator.free(err);
                try runtime_error(expr.paren.line, err);
                return InterpreterError.NotACallable;
            }

            const func = callee.Callable.call;

            return try func(callee.Callable.stmt, self, args, callee.Callable.env);
        } else if (callee == LiteralValue.Class) {
            var classInst = ClassInstance.init(self.allocator, @constCast(callee.Class.name));
            try self.to_free3.append(&classInst);
            const lit = LiteralValue{
                .ClassInstance = classInst,
            };

            return lit;
        }
        try runtime_error(expr.paren.line, "Can only call funcitons and classes");
        return InterpreterError.ArgumentMismatch;
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

    fn evaluvate_assign(self: *Self, expr: *Expr) anyerror!?LiteralValue {
        const val = try self.evaluvate(expr.assign.value) orelse return null;

        // var res = std.ArrayList(u8).init(self.allocator);
        // try expr.to_string(&res);
        // try self.to_free2.append(res);
        const distance = self.locals.get(expr);
        if (distance) |d| {
            try self.environment.assign_at(d, expr.assign.name, val);
        } else {
            try self.globals.assign(expr.assign.name, val);
        }
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
            LiteralValue.Class => return true,
            LiteralValue.ClassInstance => return true,
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

    pub fn resolve(self: *Self, expr: *Expr, depth: u64) !void {
        // var res = std.ArrayList(u8).init(self.allocator);
        // try expr.to_string(&res);
        // try self.to_free2.append(res);
        try self.locals.put(expr, depth);
    }
};
