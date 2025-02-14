const std = @import("std");
const Expr = @import("./expr.zig").Expr;
const Token = @import("./token.zig").Token;

const expr_stmt = struct {
    expr: *Expr,
};

const block_stmt = struct { stmts: []*Stmt };

const print_stmt = struct {
    expr: *Expr,
};

const var_stmt = struct {
    name: Token,
    initializer: ?*Expr,
};

pub const Stmt = union(enum) {
    expr_stmt: expr_stmt,
    print_stmt: print_stmt,
    var_stmt: var_stmt,
    block_stmt: block_stmt,

    pub fn to_string(self: Stmt, res: *std.ArrayList(u8)) !void {
        switch (self) {
            Stmt.expr_stmt => try self.expr_stmt.expr.to_string(res),
            Stmt.print_stmt => try self.print_stmt.expr.to_string(res),
            Stmt.var_stmt => {},
        }
    }
};
