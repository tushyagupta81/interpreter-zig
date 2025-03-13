const std = @import("std");
const LiteralValue = @import("./token.zig").LiteralValue;
const Token = @import("./token.zig").Token;
const runtime_error = @import("./main.zig").runtime_error;

pub const Environment = struct {
    const Self = @This();

    values: std.StringHashMap(LiteralValue),
    enclosing: ?*Environment,
    allocator: std.mem.Allocator,
    to_free: std.ArrayList([]u8),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .enclosing = null,
            .values = std.StringHashMap(LiteralValue).init(allocator),
            .to_free = std.ArrayList([]u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit();
        for (self.to_free.items) |item| {
            self.allocator.free(item);
        }
        self.to_free.deinit();
    }

    pub fn define(self: *Self, name: Token, value: LiteralValue) !void {
        // NOTE: dupe the lexeme here cause it gets freed in the repl mode on the next line
        // NOTE: No more duping we store this shit in a array and free all that later
        // duping causes memory leaks
        const n = try self.allocator.dupe(u8, name.lexeme);
        try self.to_free.append(n);
        try self.values.put(n, value);
    }

    pub fn assign_at(self: *Self, distance: u64, name: Token, value: LiteralValue) !void {
        const an = self.ancestor(distance);
        const n = try an.allocator.dupe(u8, name.lexeme);
        try an.to_free.append(n);
        try an.values.put(n, value);
    }

    pub fn assign(self: *Self, name: Token, value: LiteralValue) !void {
        if (self.values.contains(name.lexeme)) {
            // dupe the lexeme here cause it gets freed in the repl mode on the next line
            const n = try self.allocator.dupe(u8, name.lexeme);
            try self.to_free.append(n);
            try self.values.put(n, value);
            return;
        }
        if (self.enclosing) |enc| {
            try enc.assign(name, value);
            return;
        }
        var buf: [4096]u8 = undefined;
        try runtime_error(name.line, try std.fmt.bufPrint(&buf, "Undefined variable '{s}'", .{name.lexeme}));
    }

    fn ancestor(self: *Self, distance: u64) *Self {
        var env = self;
        var i: i32 = 0;
        while (i < distance) : (i += 1) {
            env = env.enclosing.?;
        }

        return env;
    }

    pub fn get_at(self: *Self, distance: u64, name: Token) !?LiteralValue {
        const an = self.ancestor(distance);
        return an.values.get(name.lexeme);
    }

    pub fn get(self: *Self, name: Token) !?LiteralValue {
        // var it = self.values.iterator();
        // while (it.next()) |v| {
        //     std.debug.print("{s}\n", .{v.key_ptr.*});
        // }
        // std.debug.print("\n\n\n", .{});
        if (self.values.get(name.lexeme)) |value| {
            return value;
        }
        if (self.enclosing) |enc| {
            return try enc.get(name);
        }
        var buf: [4096]u8 = undefined;
        try runtime_error(name.line, try std.fmt.bufPrint(&buf, "Undefined variable '{s}'", .{name.lexeme}));
        return null;
    }

    pub fn get_no_warn(self: *Self, name: Token) !?LiteralValue {
        if (self.values.get(name.lexeme)) |value| {
            return value;
        }
        if (self.enclosing) |enc| {
            return try enc.get(name);
        }
        return null;
    }
};
