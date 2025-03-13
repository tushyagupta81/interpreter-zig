const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Token = @import("./token.zig").Token;
const LiteralValue = @import("./token.zig").LiteralValue;

pub const AssignExpr = struct {
    name: Token,
    value: *Expr,
};

pub const callExpr = struct {
    callee: *Expr,
    paren: Token,
    arguments: std.ArrayList(*Expr),
};

pub const VariableExpr = struct {
    name: Token,
};

pub const BinaryExpr = struct {
    left: *Expr,
    op: Token,
    right: *Expr,
};

pub const GroupingExpr = struct {
    expression: *Expr,
};

pub const LiteralExpr = struct {
    value: LiteralValue,
};

pub const UnaryExpr = struct {
    op: Token,
    right: *Expr,
};

pub const LogicalExpr = struct {
    left: *Expr,
    op: Token,
    right: *Expr,
};

pub const GetExpr = struct {
    object: *Expr,
    name: Token,
};

pub const Expr = union(enum) {
    const Self = @This();

    binary: BinaryExpr,
    grouping: GroupingExpr,
    unary: UnaryExpr,
    literal: LiteralExpr,
    variable: VariableExpr,
    assign: AssignExpr,
    logical: LogicalExpr,
    callExpr: callExpr,
    getExpr: GetExpr,

    pub fn to_string(expr: Expr, res: *std.ArrayList(u8)) !void {
        switch (expr) {
            Expr.binary => |e| {
                try res.appendSlice("( ");
                try e.left.to_string(res);
                try res.appendSlice(" ");
                try res.appendSlice(e.op.lexeme);
                try res.appendSlice(" ");
                try e.right.to_string(res);
                try res.appendSlice(" )");
            },
            Expr.grouping => |e| {
                try res.appendSlice("(group ");
                try e.expression.to_string(res);
                try res.appendSlice(")");
            },
            Expr.unary => |e| {
                try res.appendSlice("( ");
                try res.appendSlice(e.op.lexeme);
                try res.appendSlice(" ");
                try e.right.to_string(res);
                try res.appendSlice(" )");
            },
            Expr.literal => |e| {
                try res.appendSlice(try e.value.to_string());
            },
            Expr.variable => |e| {
                try res.appendSlice(e.name.lexeme);
            },
            Expr.assign => |e| {
                try res.appendSlice(e.name.lexeme);
                try e.value.to_string(res);
            },
            Expr.logical => |e| {
                try e.left.to_string(res);
                try res.appendSlice(e.op.lexeme);
                try e.right.to_string(res);
            },
            Expr.callExpr => |e| {
                try e.callee.to_string(res);
                try res.appendSlice(e.paren.lexeme);
                for (e.arguments.items) |arg| {
                    try arg.to_string(res);
                }
            },
            else => {},
        }
    }
};

// Beautiful work of https://github.com/tusharhero/zlox/tree/master
pub const ExprIntHashMap = std.HashMap(
    *Expr,
    u64,
    struct {
        const Context = @This();
        pub fn hash(context: Context, expression: *Expr) u64 {
            var h = std.hash.Wyhash.init(0);
            h.update(std.mem.asBytes(&@intFromEnum(expression.*)));
            switch (expression.*) {
                .unary => |unary| {
                    h.update(std.mem.asBytes(&@intFromEnum(unary.op.type)));
                    h.update(std.mem.asBytes(&hash(context, unary.right)));
                },
                .binary => |binary| {
                    h.update(std.mem.asBytes(&@intFromEnum(binary.op.type)));
                    h.update(std.mem.asBytes(&hash(context, binary.left)));
                    h.update(std.mem.asBytes(&hash(context, binary.right)));
                },
                .logical => |binary| {
                    h.update(std.mem.asBytes(&@intFromEnum(binary.op.type)));
                    h.update(std.mem.asBytes(&hash(context, binary.left)));
                    h.update(std.mem.asBytes(&hash(context, binary.right)));
                },
                .grouping => |grouping| {
                    h.update(std.mem.asBytes(&hash(context, grouping.expression)));
                },
                .literal => |literal| {
                    h.update(std.mem.asBytes(&@intFromEnum(literal.value)));
                    switch (literal.value) {
                        .String => |str| h.update(str),
                        .Bool => |boolean| h.update(std.mem.asBytes(&@intFromBool(boolean))),
                        .Float => |num| h.update(std.mem.asBytes(&num)),
                        .Callable => |callable| h.update(std.mem.asBytes(&callable.arity)),
                        .Class => |class| h.update(std.mem.asBytes(&class.name)),
                        .Nil => {},
                        else => {},
                    }
                },
                .variable => |variable| h.update(std.mem.asBytes(&variable)),
                .assign => |assignment| {
                    h.update(std.mem.asBytes(&assignment.name.lexeme));
                    h.update(std.mem.asBytes(&hash(context, assignment.value)));
                },
                .callExpr => |call| {
                    h.update(std.mem.asBytes(&@intFromEnum(call.paren.type)));
                    h.update(std.mem.asBytes(&hash(context, call.callee)));
                    for (call.arguments.items) |argument|
                        h.update(std.mem.asBytes(&hash(context, argument)));
                },
                else => {},
            }
            return h.final();
        }
        pub fn eql(context: Context, a: *Expr, b: *Expr) bool {
            if (@intFromEnum(a.*) != @intFromEnum(b.*)) return false;
            switch (a.*) {
                .binary => {
                    if (a.binary.op.type != a.binary.op.type) return false;
                    if (!eql(context, a.binary.left, b.binary.left)) return false;
                    if (!eql(context, a.binary.right, b.binary.right)) return false;
                },
                .logical => {
                    if (a.logical.op.type != a.logical.op.type) return false;
                    if (!eql(context, a.logical.left, b.logical.left)) return false;
                    if (!eql(context, a.logical.right, b.logical.right)) return false;
                },
                .grouping => {
                    if (!eql(context, a.grouping.expression, b.grouping.expression)) return false;
                },
                .literal => {
                    if (@intFromEnum(a.literal.value) != @intFromEnum(b.literal.value)) return false;
                    switch (a.literal.value) {
                        .Float => if (a.literal.value.Float != b.literal.value.Float) return false,
                        .Bool => if (a.literal.value.Bool != b.literal.value.Bool) return false,
                        .String => if (!std.mem.eql(u8, a.literal.value.String, b.literal.value.String))
                            return false,
                        .Nil => {},
                        .Callable => {
                            if (a.literal.value.Callable.arity != b.literal.value.Callable.arity) return false;
                            if (@intFromPtr(a.literal.value.Callable.call) != @intFromPtr(b.literal.value.Callable.call)) return false;
                        },
                        .Class => {
                            if (!std.mem.eql(u8, a.literal.value.Class.name.lexeme, b.literal.value.Class.name.lexeme)) return false;
                        },
                        else => {},
                    }
                },
                .unary => {
                    if (a.unary.op.type != a.unary.op.type) return false;
                    if (!eql(context, a.unary.right, b.unary.right)) return false;
                },
                .variable => {
                    if (!std.mem.eql(u8, a.variable.name.lexeme, b.variable.name.lexeme)) return false;
                    if (a.variable.name.line != b.variable.name.line) return false;
                    if (a.variable.name.line != b.variable.name.line) return false;
                    if (a.variable.name.literal != null and b.variable.name.literal != null) {
                        if (@intFromEnum(a.variable.name.literal.?) != @intFromEnum(b.variable.name.literal.?)) return false;
                        switch (a.variable.name.literal.?) {
                            .Float => if (a.variable.name.literal.?.Float != b.variable.name.literal.?.Float) return false,
                            .Bool => if (a.variable.name.literal.?.Bool != b.variable.name.literal.?.Bool) return false,
                            .String => if (!std.mem.eql(u8, a.variable.name.literal.?.String, b.variable.name.literal.?.String))
                                return false,
                            .Nil => {},
                            .Callable => {
                                if (a.variable.name.literal.?.Callable.arity != b.variable.name.literal.?.Callable.arity) return false;
                                if (@intFromPtr(a.variable.name.literal.?.Callable.call) != @intFromPtr(b.variable.name.literal.?.Callable.call)) return false;
                            },
                            .Class => {
                                if (!std.mem.eql(u8, a.variable.name.literal.?.Class.name.lexeme, b.variable.name.literal.?.Class.name.lexeme)) return false;
                            },
                            else => {},
                        }
                    }
                    if (!std.mem.eql(u8, std.mem.asBytes(&a.variable), std.mem.asBytes(&b.variable))) return false;
                },
                .assign => {
                    if (!std.mem.eql(u8, a.assign.name.lexeme, b.assign.name.lexeme)) return false;
                    if (!eql(context, a.assign.value, b.assign.value)) return false;
                },
                .callExpr => {
                    if (!eql(context, a.callExpr.callee, b.callExpr.callee)) return false;
                    if (a.callExpr.paren.line != a.callExpr.paren.line) return false;
                    if (a.callExpr.arguments.items.len != 0 and b.callExpr.arguments.items.len != 0) {
                        for (a.callExpr.arguments.items, b.callExpr.arguments.items) |argumentA, argumentB| {
                            if (!eql(context, argumentA, argumentB)) return false;
                        }
                    }
                },
                else => {},
            }
            return true;
        }
    },
    std.hash_map.default_max_load_percentage,
);
