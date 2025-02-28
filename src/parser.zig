const std = @import("std");
const Expr = @import("./expr.zig").Expr;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;
const LiteralValue = @import("./token.zig").LiteralValue;
const Stmt = @import("./statement.zig").Stmt;
const parse_error = @import("./main.zig").parse_error;

const ParseError = error{
    ExpectedRightParen,
    ExpectedLeftParen,
    ExpectedExpresion,
    ExpectedSemicolon,
    ExpectedVariableName,
    ExpectedRightBrace,
    ExpectedLeftBrace,
    ExpectedFunctionName,
    TooManyArgs,
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
            const stmt = self.declaration() catch |err| {
                switch (err) {
                    ParseError.ExpectedRightParen => try parse_error(self.peek(), "Expected Right Parenthesis.", self.allocator),
                    ParseError.ExpectedExpresion => try parse_error(self.peek(), "Expected Expression.", self.allocator),
                    ParseError.ExpectedSemicolon => try parse_error(self.peek(), "Expected Semicolon after Expression.", self.allocator),
                    ParseError.ExpectedVariableName => try parse_error(self.peek(), "Expected Variable name", self.allocator),
                    ParseError.ExpectedRightBrace => try parse_error(self.peek(), "Expected closing brace", self.allocator),
                    ParseError.TooManyArgs => try parse_error(self.peek(), "Can't have more than 255 arguments", self.allocator),
                    else => return err,
                }
                self.syncronize();
                continue;
            };
            try stmts.append(stmt);
        }
        return stmts;
    }

    fn declaration(self: *Self) anyerror!*Stmt {
        if (self.match(&[_]TokenType{TokenType.Fun})) {
            return try self.function("function");
        } else if (self.match(&[_]TokenType{TokenType.Var})) {
            return try self.var_declaration();
        } else {
            return try self.statement();
        }
    }

    fn function(self: *Self, _: []const u8) anyerror!*Stmt {
        const name = try self.consume(TokenType.Identifier, ParseError.ExpectedFunctionName);
        _ = try self.consume(TokenType.Left_paren, ParseError.ExpectedLeftParen);
        var params = std.ArrayList(Token).init(self.allocator);
        if (!self.check(TokenType.Right_paren)) {
            while (true) {
                if (params.items.len >= 255) {
                    try parse_error(self.peek(), "Can't have more than 255 parameters", self.allocator);
                }

                try params.append(try self.consume(TokenType.Identifier, ParseError.ExpectedVariableName));
                if (!self.match(&[_]TokenType{TokenType.Comma})) {
                    break;
                }
            }
        }

        _ = try self.consume(TokenType.Right_paren, ParseError.ExpectedRightParen);

        _ = try self.consume(TokenType.Left_brace, ParseError.ExpectedRightBrace);
        const body = try self.block_statement();
        const stmt = try self.allocator.create(Stmt);
        stmt.* = Stmt{
            .funcStmt = .{
                .name = name,
                .params = params,
                .body = body.block_stmt.stmts,
            },
        };
        return stmt;
    }

    fn var_declaration(self: *Self) anyerror!*Stmt {
        const name = try self.consume(TokenType.Identifier, ParseError.ExpectedVariableName);

        var initializer: ?*Expr = null;
        if (self.match(&[_]TokenType{TokenType.Equal})) {
            initializer = try self.expression();
        }

        _ = try self.consume(TokenType.Semicolon, ParseError.ExpectedSemicolon);

        const stmt = try self.allocator.create(Stmt);
        stmt.* = Stmt{
            .var_stmt = .{
                .name = name,
                .initializer = initializer,
            },
        };
        return stmt;
    }

    fn statement(self: *Self) anyerror!*Stmt {
        if (self.match(&[_]TokenType{TokenType.If})) {
            return try self.if_statement();
        } else if (self.match(&[_]TokenType{TokenType.For})) {
            return try self.for_statement();
        } else if (self.match(&[_]TokenType{TokenType.While})) {
            return try self.while_statement();
        } else if (self.match(&[_]TokenType{TokenType.Print})) {
            return try self.print_statement();
        } else if (self.match(&[_]TokenType{TokenType.Left_brace})) {
            return try self.block_statement();
        }

        return try self.expr_statement();
    }

    fn for_statement(self: *Self) !*Stmt {
        _ = try self.consume(TokenType.Left_paren, ParseError.ExpectedLeftParen);

        var initializer: ?*Stmt = undefined;
        if (self.match(&[_]TokenType{TokenType.Semicolon})) {
            initializer = null;
        } else if (self.match(&[_]TokenType{TokenType.Var})) {
            initializer = try self.var_declaration();
        } else {
            initializer = try self.expr_statement();
        }

        var cond: *Expr = undefined;
        if (!self.check(TokenType.Semicolon)) {
            cond = try self.expression();
        } else {
            const cond_expr = try self.allocator.create(Expr);
            cond_expr.* = Expr{
                .literal = .{
                    .value = LiteralValue{ .Bool = true },
                },
            };
            cond = cond_expr;
        }
        _ = try self.consume(TokenType.Semicolon, ParseError.ExpectedSemicolon);

        var inc: ?*Expr = null;
        if (!self.check(TokenType.Right_paren)) {
            inc = try self.expression();
        }

        _ = try self.consume(TokenType.Right_paren, ParseError.ExpectedRightParen);

        const body_old = try self.statement();

        const body = try self.allocator.create(Stmt);
        const stmt = try self.allocator.create(Stmt);
        if (inc) |i| {
            const inc_stmt = try self.allocator.create(Stmt);
            inc_stmt.* = Stmt{
                .expr_stmt = .{
                    .expr = i,
                },
            };
            var stmts = std.ArrayList(*Stmt).init(self.allocator);
            try stmts.append(body_old);
            try stmts.append(inc_stmt);
            body.* = Stmt{
                .block_stmt = .{
                    .stmts = stmts.items,
                },
            };
            stmt.* = Stmt{
                .while_stmt = .{
                    .condition = cond,
                    .body = body,
                },
            };
        } else {
            stmt.* = Stmt{
                .while_stmt = .{
                    .condition = cond,
                    .body = body_old,
                },
            };
        }

        if (initializer) |initial| {
            var stmts = std.ArrayList(*Stmt).init(self.allocator);
            try stmts.append(initial);
            try stmts.append(stmt);
            const body_final = try self.allocator.create(Stmt);
            body_final.* = Stmt{
                .block_stmt = .{
                    .stmts = stmts.items,
                },
            };
            return body_final;
        }

        return stmt;
    }

    fn while_statement(self: *Self) !*Stmt {
        _ = try self.consume(TokenType.Left_paren, ParseError.ExpectedLeftParen);
        const cond = try self.expression();
        _ = try self.consume(TokenType.Right_paren, ParseError.ExpectedRightParen);

        const body = try self.statement();

        const stmt = try self.allocator.create(Stmt);
        stmt.* = Stmt{
            .while_stmt = .{
                .condition = cond,
                .body = body,
            },
        };
        return stmt;
    }

    fn if_statement(self: *Self) !*Stmt {
        _ = try self.consume(TokenType.Left_paren, ParseError.ExpectedLeftParen);
        const cond = try self.expression();
        _ = try self.consume(TokenType.Right_paren, ParseError.ExpectedRightParen);

        const then_branch = try self.statement();
        var else_branch: ?*Stmt = null;
        if (self.match(&[_]TokenType{TokenType.Else})) {
            else_branch = try self.statement();
        }

        const stmt = try self.allocator.create(Stmt);
        stmt.* = Stmt{
            .if_stmt = .{
                .condition = cond,
                .then_branch = then_branch,
                .else_branch = else_branch,
            },
        };
        return stmt;
    }

    fn block_statement(self: *Self) !*Stmt {
        var stmts = std.ArrayList(*Stmt).init(self.allocator);
        while (!self.check(TokenType.Right_brace) and !self.is_at_end()) {
            try stmts.append(try self.declaration());
        }
        _ = try self.consume(TokenType.Right_brace, ParseError.ExpectedRightBrace);

        const stmt = try self.allocator.create(Stmt);
        stmt.* = Stmt{
            .block_stmt = .{
                .stmts = stmts.items,
            },
        };
        return stmt;
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
        return try self.assignment();
    }

    fn assignment(self: *Self) anyerror!*Expr {
        const left = try self.or_();

        if (self.match(&[_]TokenType{TokenType.Equal})) {
            _ = self.previous();
            const val = try self.assignment();
            if (left.* == Expr.variable) {
                const name = left.variable.name;
                const assign_expr = try self.allocator.create(Expr);
                assign_expr.* = Expr{
                    .assign = .{
                        .name = name,
                        .value = val,
                    },
                };
                return assign_expr;
            }
        }

        return left;
    }

    fn or_(self: *Self) anyerror!*Expr {
        const left = try self.and_();

        if (self.match(&[_]TokenType{TokenType.Or})) {
            const op = self.previous();
            const right = try self.and_();
            const or_expr = try self.allocator.create(Expr);
            or_expr.* = Expr{
                .logical = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            return or_expr;
        }

        return left;
    }

    fn and_(self: *Self) anyerror!*Expr {
        const left = try self.equality();

        if (self.match(&[_]TokenType{TokenType.And})) {
            const op = self.previous();
            const right = try self.equality();
            const or_expr = try self.allocator.create(Expr);
            or_expr.* = Expr{
                .logical = .{
                    .left = left,
                    .op = op,
                    .right = right,
                },
            };
            return or_expr;
        }

        return left;
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

        return try self.call();
    }

    fn call(self: *Self) anyerror!*Expr {
        var expr = try self.primary();

        while (true) {
            if (self.match(&[_]TokenType{TokenType.Left_paren})) {
                expr = try self.finishCall(expr);
            } else {
                break;
            }
        }

        return expr;
    }

    fn finishCall(self: *Self, callee: *Expr) anyerror!*Expr {
        var args = std.ArrayList(*Expr).init(self.allocator);
        if (!self.check(TokenType.Right_paren)) {
            while (true) {
                if (args.items.len >= 255) {
                    return ParseError.TooManyArgs;
                }
                try args.append(try self.expression());
                if (!self.match(&[_]TokenType{TokenType.Comma})) {
                    break;
                }
            }
        }

        const paren = try self.consume(TokenType.Right_paren, ParseError.ExpectedRightParen);

        const expr = try self.allocator.create(Expr);
        expr.* = Expr{
            .callExpr = .{
                .arguments = args,
                .callee = callee,
                .paren = paren,
            },
        };
        return expr;
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
        if (self.match(&[_]TokenType{TokenType.Identifier})) {
            const name = self.previous();
            const variable = try self.allocator.create(Expr);
            variable.* = Expr{
                .variable = .{
                    .name = name,
                },
            };
            return variable;
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
