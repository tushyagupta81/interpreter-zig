const std = @import("std");
const Expr = @import("./expr.zig").Expr;
const Token = @import("./token.zig").Token;

const class_stmt = struct {
    name: Token,
    methods: []*Stmt,
};

const expr_stmt = struct {
    expr: *Expr,
};

const while_stmt = struct {
    condition: *Expr,
    body: *Stmt,
};

const if_stmt = struct {
    condition: *Expr,
    then_branch: *Stmt,
    else_branch: ?*Stmt,
};

const block_stmt = struct {
    stmts: []*Stmt,
};

const print_stmt = struct {
    expr: *Expr,
};

const var_stmt = struct {
    name: Token,
    initializer: ?*Expr,
};

const return_stmt = struct {
    keyword: Token,
    value: ?*Expr,
};

const func_stmt = struct {
    name: Token,
    params: std.ArrayList(Token),
    body: []*Stmt,
};

pub const Stmt = union(enum) {
    expr_stmt: expr_stmt,
    print_stmt: print_stmt,
    var_stmt: var_stmt,
    block_stmt: block_stmt,
    if_stmt: if_stmt,
    while_stmt: while_stmt,
    func_stmt: func_stmt,
    return_stmt: return_stmt,
    class_stmt: class_stmt,

    pub fn to_string(self: Stmt, res: *std.ArrayList(u8)) !void {
        switch (self) {
            Stmt.expr_stmt => try self.expr_stmt.expr.to_string(res),
            Stmt.print_stmt => try self.print_stmt.expr.to_string(res),
            Stmt.var_stmt => {},
        }
    }
};
