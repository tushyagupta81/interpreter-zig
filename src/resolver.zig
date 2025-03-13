const std = @import("std");
const stdout = std.io.getStdOut().writer();
const LiteralValue = @import("./token.zig").LiteralValue;
const Environment = @import("./environment.zig").Environment;
const TokenType = @import("./token.zig").TokenType;
const Expr = @import("./expr.zig").Expr;
const Token = @import("./token.zig").Token;
const Stmt = @import("./statement.zig").Stmt;
const Interpreter = @import("interpreter.zig").Interpreter;
const parse_error = @import("./main.zig").parse_error;

pub const Resolver = struct {
    const Self = @This();

    interpreter: *Interpreter,
    allocator: std.mem.Allocator,
    scopes: std.ArrayList(*std.StringHashMap(bool)),
    to_free: std.ArrayList([]u8),

    pub fn init(allocator: std.mem.Allocator, interpreter: *Interpreter) !Self {
        return Self{
            .interpreter = interpreter,
            .allocator = allocator,
            .scopes = std.ArrayList(*std.StringHashMap(bool)).init(allocator),
            .to_free = std.ArrayList([]u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.to_free.items) |item| {
            self.allocator.free(item);
        }
        self.to_free.deinit();
        for (self.scopes.items) |scope| {
            scope.deinit();
            self.allocator.destroy(scope);
        }
        self.scopes.deinit();
    }

    pub fn resolve_stmts(self: *Self, stmts: []*Stmt) anyerror!void {
        for (stmts) |stmt| {
            try self.resolve_stmt(stmt);
        }
    }

    fn resolve_stmt(self: *Self, stmt: *Stmt) anyerror!void {
        try self.evaluvate_stmt(stmt);
    }

    fn resolve_expr(self: *Self, expr: *Expr) anyerror!void {
        try self.evaluvate(expr);
    }

    fn evaluvate_stmt(self: *Self, stmt: *Stmt) anyerror!void {
        switch (stmt.*) {
            Stmt.expr_stmt => {
                try self.resolve_expr(stmt.expr_stmt.expr);
            },
            Stmt.print_stmt => {
                try self.resolve_expr(stmt.print_stmt.expr);
            },
            Stmt.var_stmt => {
                if (stmt.var_stmt.initializer) |initializer| {
                    try self.resolve_expr(initializer);
                }
                try self.define(stmt.var_stmt.name);
            },
            Stmt.block_stmt => {
                try self.begin_scope();
                try self.resolve_stmts(stmt.block_stmt.stmts);
                try self.end_scope();
            },
            Stmt.if_stmt => {
                try self.resolve_expr(stmt.if_stmt.condition);
                try self.resolve_stmt(stmt.if_stmt.then_branch);
                if (stmt.if_stmt.else_branch) |else_branch| {
                    try self.resolve_stmt(else_branch);
                }
            },
            Stmt.while_stmt => {
                try self.resolve_expr(stmt.while_stmt.condition);
                try self.resolve_stmt(stmt.while_stmt.body);
            },
            Stmt.funcStmt => {
                try self.declare(stmt.funcStmt.name);
                try self.define(stmt.funcStmt.name);

                try self.resolve_function(stmt);
            },
            Stmt.return_stmt => {
                if (stmt.return_stmt.value) |val| {
                    try self.resolve_expr(val);
                }
            },
        }
    }

    fn evaluvate(self: *Self, expr: *Expr) anyerror!void {
        switch (expr.*) {
            Expr.unary => {
                try self.resolve_expr(expr.unary.right);
            },
            Expr.binary => {
                try self.resolve_expr(expr.binary.left);
                try self.resolve_expr(expr.binary.right);
            },
            Expr.grouping => {
                try self.resolve_expr(expr.grouping.expression);
            },
            Expr.literal => {
                // This is empty and stays like this
            },
            Expr.variable => {
                if (self.scopes.items.len != 0) {
                    if (self.scopes.getLast().*.get(expr.variable.name.lexeme)) |v| {
                        if (v == false) {
                            try parse_error(expr.variable.name, "Can't read local variable in its own initializer", self.allocator);
                        }
                    }
                }

                try self.resolve_local(expr, expr.variable.name);
            },
            Expr.assign => {
                try self.resolve_expr(expr.assign.value);
                try self.resolve_local(expr, expr.assign.name);
            },
            Expr.logical => {
                try self.resolve_expr(expr.logical.left);
                try self.resolve_expr(expr.logical.right);
            },
            Expr.callExpr => {
                try self.resolve_expr(expr.callExpr.callee);

                for (expr.callExpr.arguments.items) |arg| {
                    try self.resolve_expr(arg);
                }
            },
        }
    }

    fn resolve_local(self: *Self, expr: *Expr, name: Token) anyerror!void {
        for (self.scopes.items, 0..) |_, i| {
            if (self.scopes.items[i].contains(name.lexeme)) {
                try self.interpreter.resolve(expr, @intCast(self.scopes.items.len - 1 - i));
                return;
            }
        }
    }

    fn resolve_function(self: *Self, stmt: *Stmt) anyerror!void {
        try self.begin_scope();
        for (stmt.funcStmt.params.items) |param| {
            try self.declare(param);
            try self.define(param);
        }
        try self.resolve_stmts(stmt.funcStmt.body);
        try self.end_scope();
    }

    fn begin_scope(self: *Self) anyerror!void {
        const scope = try self.allocator.create(std.StringHashMap(bool));
        scope.* = std.StringHashMap(bool).init(self.allocator);
        try self.scopes.append(scope);
    }

    fn end_scope(self: *Self) anyerror!void {
        _ = self.scopes.pop();
    }

    fn declare(self: *Self, name: Token) anyerror!void {
        if (self.scopes.items.len == 0) return;
        var scope = self.scopes.getLast();
        const dupe_name = try self.allocator.dupe(u8, name.lexeme);
        try self.to_free.append(dupe_name);
        try scope.put(dupe_name, false);
    }

    fn define(self: *Self, name: Token) anyerror!void {
        if (self.scopes.items.len == 0) return;
        var scope = self.scopes.getLast();
        const dupe_name = try self.allocator.dupe(u8, name.lexeme);
        try self.to_free.append(dupe_name);
        try scope.put(dupe_name, true);
    }
};
