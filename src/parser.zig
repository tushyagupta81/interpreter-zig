const std = @import("std");
const Expr = @import("./expr.zig").Expr;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const LiteralValue = @import("./token.zig").LiteralValue;
const Stmt = @import("./statement.zig").Stmt;
const parse_error = @import("./main.zig").parse_error;

const ParseError = error{
    ExpectedRightParen,
    ExpectedExpresion,
    ExpectedSemicolon,
};

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

    // pub fn parse(self: *Self) anyerror!*Expr {
    //     return try self.expression();
    // }

    pub fn parse(self: *Self) anyerror!std.ArrayList(*Stmt) {
        var stmts = std.ArrayList(*Stmt).init(self.allocator);
        while (!self.is_at_end()) {
            const stmt = self.statement() catch |err| {
                switch (err) {
                    ParseError.ExpectedRightParen => try parse_error(self.peek(), "Expected Right Parenthesis.", self.allocator),
                    ParseError.ExpectedExpresion => try parse_error(self.peek(), "Expected Expression.", self.allocator),
                    ParseError.ExpectedSemicolon => try parse_error(self.peek(), "Expected Semicolon after Expression.", self.allocator),
                    else => return err,
                }
                self.syncronize();
                continue;
            };
            try stmts.append(stmt);
        }
        return stmts;
    }

    fn statement(self: *Self) anyerror!*Stmt {
        if (self.match(&[_]TokenType{TokenType.Print})) {
            return try self.print_statement();
        }

        return try self.expr_statement();
    }

    fn print_statement(self: *Self) !*Stmt {
        const expr = try self.expression();
        _ = try self.consume(TokenType.Semicolon, ParseError.ExpectedSemicolon);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = Stmt{
            .print_stmt = .{
                .expr = expr,
            },
        };
        return stmt;
    }

    fn expr_statement(self: *Self) !*Stmt {
        const expr = try self.expression();
        _ = try self.consume(TokenType.Semicolon, ParseError.ExpectedSemicolon);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = Stmt{
            .expr_stmt = .{
                .expr = expr,
            },
        };
        return stmt;
    }

    fn expression(self: *Self) anyerror!*Expr {
        return try self.equality();
    }

    fn equality(self: *Self) anyerror!*Expr {
        var left = try self.comparision();

        while (self.match(&[_]TokenType{ TokenType.Bang_equal, TokenType.Equal_equal })) {
            const op = self.previous();
            const right = try self.comparision();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{
                .binary = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = binary_expr;
        }

        return left;
    }

    fn comparision(self: *Self) anyerror!*Expr {
        var left = try self.term();

        while (self.match(&[_]TokenType{ TokenType.Greater, TokenType.Less, TokenType.Greater_equal, TokenType.Less_equal })) {
            const op = self.previous();
            const right = try self.term();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{
                .binary = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = binary_expr;
        }

        return left;
    }

    fn term(self: *Self) anyerror!*Expr {
        var left = try self.factor();

        while (self.match(&[_]TokenType{ TokenType.Minus, TokenType.Plus })) {
            const op = self.previous();
            const right = try self.factor();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{
                .binary = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = binary_expr;
        }

        return left;
    }

    fn factor(self: *Self) anyerror!*Expr {
        var left = try self.unary();

        while (self.match(&[_]TokenType{ TokenType.Star, TokenType.Slash })) {
            const op = self.previous();
            const right = try self.unary();
            const binary_expr = try self.allocator.create(Expr);
            binary_expr.* = Expr{
                .binary = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            left = binary_expr;
        }

        return left;
    }

    fn unary(self: *Self) anyerror!*Expr {
        if (self.match(&[_]TokenType{ TokenType.Bang, TokenType.Minus })) {
            const op = self.previous();
            const right = try self.unary();
            const unary_expr = try self.allocator.create(Expr);
            unary_expr.* = Expr{
                .unary = .{
                    .op = op,
                    .right = right,
                },
            };
            return unary_expr;
        } else if (self.match(&[_]TokenType{
            TokenType.Star,
            TokenType.Slash,
            TokenType.Plus,
            TokenType.Greater,
            TokenType.Less,
            TokenType.Greater_equal,
            TokenType.Less_equal,
            TokenType.Bang_equal,
            TokenType.Equal_equal,
        })) {
            try parse_error(self.peek(), "Expected left expression", self.allocator);
        }

        return try self.primary();
    }

    fn primary(self: *Self) anyerror!*Expr {
        if (self.match(&[_]TokenType{TokenType.False})) {
            const literal = try self.allocator.create(Expr);
            literal.* = Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Bool = false,
                    },
                },
            };
            return literal;
        }
        if (self.match(&[_]TokenType{TokenType.True})) {
            const literal = try self.allocator.create(Expr);
            literal.* = Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Bool = true,
                    },
                },
            };
            return literal;
        }
        if (self.match(&[_]TokenType{TokenType.Nil})) {
            const literal = try self.allocator.create(Expr);
            literal.* = Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Nil = {},
                    },
                },
            };
            return literal;
        }
        if (self.match(&[_]TokenType{TokenType.Number})) {
            const literal = try self.allocator.create(Expr);
            literal.* = Expr{
                .literal = .{
                    .value = LiteralValue{
                        .Float = self.previous().literal.?.Float,
                    },
                },
            };
            return literal;
        }
        if (self.match(&[_]TokenType{TokenType.String})) {
            const literal = try self.allocator.create(Expr);
            literal.* = Expr{
                .literal = .{
                    .value = LiteralValue{
                        .String = self.previous().literal.?.String,
                    },
                },
            };
            return literal;
        }
        if (self.match(&[_]TokenType{TokenType.Left_paren})) {
            const expr = try self.expression();
            _ = try self.consume(TokenType.Right_paren, ParseError.ExpectedRightParen);
            const grouping = try self.allocator.create(Expr);
            grouping.* = Expr{
                .grouping = .{
                    .expression = expr,
                },
            };
            return grouping;
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

    fn consume(self: *Self, token_type: TokenType, err: ParseError) anyerror!Token {
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
