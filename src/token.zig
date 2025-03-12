const std = @import("std");
const Interpreter = @import("./interpreter.zig").Interpreter;
const Stmt = @import("./statement.zig").Stmt;
const Environment = @import("./environment.zig").Environment;

pub const TokenType = enum {
    // Single-character tokens.
    Left_paren,
    Right_paren,
    Left_brace,
    Right_brace,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,

    // ONE OR TWO CHARACTER TOKENS.
    Bang,
    Bang_equal,
    Equal,
    Equal_equal,
    Greater,
    Greater_equal,
    Less,
    Less_equal,

    // LITERALS.
    Identifier,
    String,
    Number,

    // KEYWORDS.
    And,
    Class,
    Else,
    False,
    Fun,
    For,
    If,
    Nil,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,

    Eof,
};

const callableLiteral = struct {
    // name: []const u8,
    arity: usize,
    call: *const fn (*Stmt, *Interpreter, std.ArrayList(LiteralValue), *Environment) anyerror!LiteralValue,
    stmt: *Stmt,
    env: *Environment,
};

pub const LiteralValue = union(enum) {
    const Self = @This();
    Float: f64,
    String: []u8,
    Bool: bool,
    Nil: void,
    Callable: callableLiteral,

    pub fn to_string(self: LiteralValue) ![]const u8 {
        switch (self) {
            LiteralValue.Float => {
                var buf: [4096]u8 = undefined;
                return try std.fmt.bufPrint(&buf, "{d}", .{self.Float});
                // return buf;
            },
            LiteralValue.String => {
                return self.String;
                // var buf: [4096]u8 = undefined;
                // return try std.fmt.bufPrint(&buf, "\"{s}\"", .{self.String});
            },
            LiteralValue.Bool => |v| {
                if (v) {
                    return &[_]u8{ 't', 'r', 'u', 'e' };
                } else {
                    return &[_]u8{ 'f', 'a', 'l', 's', 'e' };
                }
            },
            LiteralValue.Nil => return &[_]u8{ 'N', 'i', 'l' },
            else => return "Todo",
        }
    }
};

pub const Token = struct {
    const Self = @This();

    type: TokenType,
    lexeme: []const u8,
    literal: ?LiteralValue,
    line: u32,

    pub fn to_string(self: *const Self, allocator: *std.mem.Allocator) ![]u8 {
        if (self.literal) |lit| {
            return try std.fmt.allocPrint(allocator.*, "{s} {s} {s}\n", .{ @tagName(self.type), self.lexeme, @tagName(lit) });
        } else {
            return try std.fmt.allocPrint(allocator.*, "{s} {s}\n", .{ @tagName(self.type), self.lexeme });
        }
    }
};
