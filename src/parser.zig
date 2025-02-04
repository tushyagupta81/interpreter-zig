const std = @import("std");
const Expr = @import("./expr.zig").Expr;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const LiteralValue = @import("./token.zig").LiteralValue;
const parse_error = @import("./main.zig").parse_error;

const ParseError = error{ ExpectedRightParen, ExpectedExpresion };

pub const Parser = struct {
    const Self = @This();

    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,
    current: u32,

    pub fn init(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) Self {
        return Self{
            .tokens = tokens,
            .allocator = allocator,
            .current = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    pub fn parse(self: *Self) !std.ArrayList(Expr) {
        var exprs = std.ArrayList(Expr).init(self.allocator);
        // var errs = std.ArrayList(ParseError).init(self.allocator);
        // defer errs.deinit();
        while (!self.is_at_end()) {
            const expr = self.expression() catch |err| {
                switch (err) {
                    ParseError.ExpectedRightParen => try parse_error(self.peek(), "Expected Right Parenthesis.", self.allocator),
                    ParseError.ExpectedExpresion => try parse_error(self.peek(), "Expected Expression.", self.allocator),
                }
                self.syncronize();
                // errs.append(err);
                continue;
            };
            try exprs.append(expr);
        }
        return exprs;
    }

    fn expression(self: *Self) ParseError!Expr {
        return try self.equality();
    }

    fn equality(self: *Self) ParseError!Expr {
        var left: Expr = try self.comarision();

        while (self.match(&[_]TokenType{ TokenType.Bang_equal, TokenType.Equal_equal })) {
            var op = self.previous();
            var right = try self.comarision();
            left = Expr{
                .binary = .{
                    .left = &left,
                    .op = &op,
                    .right = &right,
                },
            };
        }

        return left;
    }

    fn comarision(self: *Self) ParseError!Expr {
        var left = try self.term();

        while (self.match(&[_]TokenType{ TokenType.Greater, TokenType.Less, TokenType.Greater_equal, TokenType.Less_equal })) {
            var op = self.previous();
            var right = try self.term();
            left = Expr{
                .binary = .{
                    .left = &left,
                    .op = &op,
                    .right = &right,
                },
            };
        }

        return left;
    }

    fn term(self: *Self) ParseError!Expr {
        var left = try self.factor();

        while (self.match(&[_]TokenType{ TokenType.Minus, TokenType.Plus })) {
            var op = self.previous();
            var right = try self.factor();
            left = Expr{
                .binary = .{
                    .left = &left,
                    .op = &op,
                    .right = &right,
                },
            };
        }

        return left;
    }

    fn factor(self: *Self) ParseError!Expr {
        var left = try self.unary();

        while (self.match(&[_]TokenType{ TokenType.Star, TokenType.Slash })) {
            var op = self.previous();
            var right = try self.unary();
            left = Expr{
                .binary = .{
                    .left = &left,
                    .op = &op,
                    .right = &right,
                },
            };
        }

        return left;
    }

    fn unary(self: *Self) ParseError!Expr {
        if (self.match(&[_]TokenType{ TokenType.Bang, TokenType.Minus })) {
            var op = self.previous();
            var right = try self.unary();
            return Expr{
                .unary = .{
                    .op = &op,
                    .right = &right,
                },
            };
        }

        return try self.primary();
    }

    fn primary(self: *Self) ParseError!Expr {
        if (self.match(&[_]TokenType{TokenType.False})) {
            return Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Bool = false,
                    },
                },
            };
        }
        if (self.match(&[_]TokenType{TokenType.True})) {
            return Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Bool = true,
                    },
                },
            };
        }
        if (self.match(&[_]TokenType{TokenType.Nil})) {
            return Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Nil = {},
                    },
                },
            };
        }
        if (self.match(&[_]TokenType{TokenType.Number})) {
            return Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Float = self.previous().literal.?.Float,
                    },
                },
            };
        }
        if (self.match(&[_]TokenType{TokenType.String})) {
            return Expr{
                .literal = .{
                    .value = LiteralValue{
                        .String = self.previous().literal.?.String,
                    },
                },
            };
        }
        if (self.match(&[_]TokenType{TokenType.Left_paren})) {
            var expr = try self.expression();
            _ = try self.consume(TokenType.Right_paren, ParseError.ExpectedRightParen);
            return Expr{
                .grouping = .{
                    .expression = &expr,
                },
            };
        }

        return ParseError.ExpectedExpresion;
    }

    fn match(self: *Self, operators: []const TokenType) bool {
        for (operators) |op| {
            if (self.check(op)) {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    fn check(self: *Self, op: TokenType) bool {
        if (self.is_at_end()) {
            return false;
        }
        return self.peek().type == op;
    }

    fn is_at_end(self: *Self) bool {
        return self.peek().type == TokenType.Eof;
    }

    fn advance(self: *Self) Token {
        if (!self.is_at_end()) {
            self.current += 1;
        }
        return self.previous();
    }

    fn peek(self: *Self) Token {
        return self.tokens.items[self.current];
    }

    fn previous(self: *Self) Token {
        return self.tokens.items[self.current - 1];
    }

    fn consume(self: *Self, token_type: TokenType, err: ParseError) ParseError!Token {
        if (self.check(token_type)) {
            return self.advance();
        }

        return err;
    }

    fn syncronize(self: *Self) void {
        _ = self.advance();

        while (!self.is_at_end()) {
            if (self.previous().type == TokenType.Semicolon) return;
            switch (self.peek().type) {
                TokenType.Class, TokenType.Fun, TokenType.Var, TokenType.For, TokenType.If, TokenType.While, TokenType.Print, TokenType.Return => return,
                else => _ = self.advance(),
            }
        }
    }
};
