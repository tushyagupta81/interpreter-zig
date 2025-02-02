const std = @import("std");

const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const LiteralValue = @import("./token.zig").LiteralValue;

const base_err = @import("./main.zig").base_error;

pub const Scanner = struct {
    const Self = @This();

    source: []u8,
    tokens: std.ArrayList(Token),
    start: u32 = 0,
    current: u32 = 0,
    line: u32 = 1,

    const keywords = std.StaticStringMap(TokenType).initComptime(.{
        .{ "and", TokenType.And },
        .{ "class", TokenType.Class },
        .{ "else", TokenType.Else },
        .{ "false", TokenType.False },
        .{ "for", TokenType.For },
        .{ "fun", TokenType.Fun },
        .{ "if", TokenType.If },
        .{ "nil", TokenType.Nil },
        .{ "or", TokenType.Or },
        .{ "print", TokenType.Print },
        .{ "return", TokenType.Return },
        .{ "super", TokenType.Super },
        .{ "this", TokenType.This },
        .{ "true", TokenType.True },
        .{ "var", TokenType.Var },
        .{ "while", TokenType.While },
    });

    pub fn init(allocator: std.mem.Allocator, source: []u8) Self {
        return .{
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    pub fn scan_tokens(self: *Self) !std.ArrayList(Token) {
        while (!self.is_at_end()) {
            self.start = self.current;
            try self.scan_token();
        }

        try self.tokens.append(Token{
            .type = TokenType.Eof,
            .lexeme = "",
            .literal = null,
            .line = self.line,
        });

        return self.tokens;
    }

    fn scan_token(self: *Self) !void {
        const c = self.advance();
        switch (c) {
            '(' => try self.add_token(TokenType.Left_paren, null),
            ')' => try self.add_token(TokenType.Right_paren, null),
            '{' => try self.add_token(TokenType.Left_brace, null),
            '}' => try self.add_token(TokenType.Right_brace, null),
            ',' => try self.add_token(TokenType.Comma, null),
            '.' => try self.add_token(TokenType.Dot, null),
            '-' => try self.add_token(TokenType.Minus, null),
            '+' => try self.add_token(TokenType.Plus, null),
            ';' => try self.add_token(TokenType.Semicolon, null),
            '*' => try self.add_token(TokenType.Star, null),

            '!' => try self.add_token(if (self.match('=')) TokenType.Bang_equal else TokenType.Bang, null),
            '=' => try self.add_token(if (self.match('=')) TokenType.Equal_equal else TokenType.Equal, null),
            '<' => try self.add_token(if (self.match('=')) TokenType.Less_equal else TokenType.Less, null),
            '>' => try self.add_token(if (self.match('=')) TokenType.Greater_equal else TokenType.Greater, null),

            '/' => {
                if (self.match('/')) {
                    while (self.peek() != '\n' and !self.is_at_end()) {
                        _ = self.advance();
                    }
                } else if (self.match('*')) {
                    while (self.peek() != '*' and self.peek_next() != '/' and !self.is_at_end()) {
                        _ = self.advance();
                    }
                    _ = self.advance();
                    _ = self.advance();
                } else {
                    try self.add_token(TokenType.Slash, null);
                }
            },

            '"' => try self.string(),

            '\n' => self.line += 1,
            ' ', '\r', '\t' => {},
            else => {
                if (std.ascii.isDigit(c)) {
                    try self.number();
                } else if (std.ascii.isAlphabetic(c) or c == '_') {
                    try self.identifier();
                } else {
                    try base_err(self.line, "Unexpected Character");
                }
            },
        }
    }

    fn identifier(self: *Self) !void {
        while (std.ascii.isAlphanumeric(self.peek())) {
            _ = self.advance();
        }

        const src = self.source[self.start..self.current];
        const token_type = keywords.get(src) orelse TokenType.Identifier;
        try self.add_token(token_type, null);
    }

    fn number(self: *Self) !void {
        while (std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }
        if (self.peek() == '.' and std.ascii.isDigit(self.peek_next())) {
            _ = self.advance();
            while (std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }
        const parsed_float = try std.fmt.parseFloat(f64, self.source[self.start..self.current]);
        const lit = LiteralValue{
            .Float = parsed_float,
        };
        try self.add_token(TokenType.Number, lit);
    }

    fn peek_next(self: *Self) u8 {
        if (self.current + 1 >= self.source.len) {
            return 0;
        } else {
            return self.source[self.current + 1];
        }
    }

    fn string(self: *Self) !void {
        while (self.peek() != '"' and !self.is_at_end()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }
        if (self.is_at_end()) {
            try base_err(self.line, "Unterminated String");
            return;
        }
        _ = self.advance();

        const string_lit = LiteralValue{
            .String = self.source[self.start + 1 .. self.current - 1],
        };
        try self.add_token(TokenType.String, string_lit);
    }

    fn peek(self: *Self) u8 {
        if (self.is_at_end()) {
            return 0;
        }
        return self.source[self.current];
    }

    fn advance(self: *Self) u8 {
        defer self.current += 1;
        return self.source[self.current];
    }

    fn match(self: *Self, c: u8) bool {
        if (self.is_at_end()) {
            return false;
        }

        if (self.source[self.current] == c) {
            self.current += 1;
            return true;
        } else {
            return false;
        }
    }

    fn add_token(self: *Self, token_type: TokenType, literal: ?LiteralValue) !void {
        try self.tokens.append(Token{
            .type = token_type,
            .lexeme = self.source[self.start..self.current],
            .literal = literal,
            .line = self.line,
        });
    }

    fn is_at_end(self: *Self) bool {
        return self.current >= self.source.len;
    }
};
