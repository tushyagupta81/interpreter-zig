const std = @import("std");

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

pub const LiteralValue = union(enum) {
    Float: f64,
    String: []u8,
    Bool: bool,
    Nil: void,
};

pub const Token = struct {
    const Self = @This();

    type: TokenType,
    lexeme: []const u8,
    literal: ?LiteralValue,
    line: u32,

    pub fn to_string(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        if (self.literal) |lit| {
            return try std.fmt.allocPrint(allocator, "{s} {s} {s}\n", .{ @tagName(self.type), self.lexeme, @tagName(lit) });
        } else {
            return try std.fmt.allocPrint(allocator, "{s} {s}\n", .{ @tagName(self.type), self.lexeme });
        }
    }
};
