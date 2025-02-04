const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Token = @import("./token.zig").Token;
const LiteralValue = @import("./token.zig").LiteralValue;

// pub const AssignExpr = struct {
//     name: *Token,
//     value: *Expr,
// };
//
// pub const BinaryExpr = struct {
//     left: *Expr,
//     op: *Token,
//     right: *Expr,
// };
//
// pub const GroupingExpr = struct {
//     expression: *Expr,
// };
//
// pub const LiteralExpr = struct {
//     value: LiteralValue,
// };
//
// pub const UnaryExpr = struct {
//     op: *Token,
//     right: *Expr,
// };

pub const Expr = union(enum) {
    const Self = @This();

    binary: struct {
        left: *Expr,
        op: *Token,
        right: *Expr,
    },
    grouping: struct {
        expression: *Expr,
    },
    unary: struct {
        op: *Token,
        right: *Expr,
    },
    literal: struct {
        value: LiteralValue,
    },
};

pub fn to_string(expr_: Expr, allocator: std.mem.Allocator, def: *std.ArrayList([]const u8)) ![]const u8 {
    switch (expr_) {
        Expr.binary => |expr| {
            const res = try std.fmt.allocPrint(allocator, "( {s} {s} {s} )", .{ try to_string(expr.left.*, allocator, def), expr.op.lexeme, try to_string(expr.right.*, allocator, def) });
            try def.append(res);
            return res;
        },
        Expr.grouping => |expr| {
            const res = try std.fmt.allocPrint(allocator, "(group {s})", .{try to_string(expr.expression.*, allocator, def)});
            try def.append(res);
            return res;
        },
        Expr.unary => |expr| {
            const res = try std.fmt.allocPrint(allocator, "( {s} {s} )", .{ expr.op.lexeme, try to_string(expr.right.*, allocator, def) });
            try def.append(res);
            return res;
        },
        Expr.literal => |expr| {
            const res = try std.fmt.allocPrint(allocator, "{s}", .{@tagName(expr.value)});
            try def.append(res);
            return res;
        },
    }
}
