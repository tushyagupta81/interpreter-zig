const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Token = @import("./token.zig").Token;
const LiteralValue = @import("./token.zig").LiteralValue;

// pub const AssignExpr = struct {
//     name: *Token,
//     value: *Expr,
// };

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

pub const Expr = union(enum) {
    const Self = @This();

    binary: BinaryExpr,
    grouping: GroupingExpr,
    unary: UnaryExpr,
    literal: LiteralExpr,
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
                // const res = try std.fmt.allocPrint(allocator.*, "{s}", .{try e.value.to_string(allocator)});
            },
        }
    }

    // binary: struct {
    //     left: *Expr,
    //     op: Token,
    //     right: *Expr,
    // },
    // grouping: struct {
    //     expression: *Expr,
    // },
    // unary: struct {
    //     op: Token,
    //     right: *Expr,
    // },
    // literal: struct {
    //     value: LiteralValue,
    // },

    // pub fn to_string(expr: Expr, allocator: *std.mem.Allocator) ![]u8 {
    //     switch (expr) {
    //         Expr.binary => |e| {
    //             const res = try std.fmt.allocPrint(allocator.*, "( {s} {s} {s} )", .{ try e.left.to_string(allocator), e.op.lexeme, try e.right.to_string(allocator) });
    //             return res;
    //         },
    //         Expr.grouping => |e| {
    //             const res = try std.fmt.allocPrint(allocator.*, "(group {s})", .{try e.expression.to_string(allocator)});
    //             return res;
    //         },
    //         Expr.unary => |e| {
    //             const res = try std.fmt.allocPrint(allocator.*, "( {s} {s} )", .{ e.op.lexeme, try e.right.*.to_string(allocator) });
    //             return res;
    //         },
    //         Expr.literal => |e| {
    //             const res = try std.fmt.allocPrint(allocator.*, "{s}", .{try e.value.to_string(allocator)});
    //             return res;
    //         },
    //     }
    // }
};
