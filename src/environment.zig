const std = @import("std");
const LiteralValue = @import("./token.zig").LiteralValue;
const Token = @import("./token.zig").Token;
const runtime_error = @import("./main.zig").runtime_error;

pub const Environment = struct {
    const Self = @This();

    values: std.StringHashMap(LiteralValue),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .values = std.StringHashMap(LiteralValue).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    pub fn define(self: *Self, name: Token, value: LiteralValue) !void {
        // dupe the lexeme here cause it gets freed in the repl mode on the next line
        try self.values.put(try self.allocator.dupe(u8, name.lexeme), value);
    }

    pub fn assign(self: *Self, name: Token, value: LiteralValue) !void {
        if (self.values.contains(name.lexeme)) {
            // dupe the lexeme here cause it gets freed in the repl mode on the next line
            try self.values.put(try self.allocator.dupe(u8, name.lexeme), value);
            return;
        }
        var buf: [4096]u8 = undefined;
        try runtime_error(name.line, try std.fmt.bufPrint(&buf, "Undefined variable '{s}'", .{name.lexeme}));
    }

    pub fn get(self: *Self, name: Token) !?LiteralValue {
        if (self.values.get(name.lexeme)) |value| {
            return value;
        }
        var buf: [4096]u8 = undefined;
        try runtime_error(name.line, try std.fmt.bufPrint(&buf, "Undefined variable '{s}'", .{name.lexeme}));
        return null;
    }
};
