const std = @import("std");

/// A generic vector type.
///
/// vec.values is a @Vector(T, n) and is meant to be used for basic operations available on @Vector types.
/// for example addition would be vec.values + other.values.
///
/// vec.len is the number of elements in the vector. and is equivaent to vec.values.len.
pub fn Vec(comptime n: usize, comptime T: type) type {
    return struct {
        const Self = @This();

        pub const len = n;

        values: @Vector(n, T),

        pub fn init(data: @Vector(n, T)) Self {
            return Self{ .values = data };
        }

        pub fn x(self: Self) T {
            if (n < 1) {
                @compileError("Vector must have at least one element for x() to be defined");
            }
            return self.values[0];
        }

        pub fn y(self: Self) T {
            if (n < 2) {
                @compileError("Vector must have at least two elements for y() to be defined");
            }
            return self.values[1];
        }

        pub fn z(self: Self) T {
            if (n < 3) {
                @compileError("Vector must have at least three elements for z() to be defined");
            }
            return self.values[2];
        }

        pub fn w(self: Self) T {
            if (n < 4) {
                @compileError("Vector must have at least four elements for w() to be defined");
            }
            return self.values[3];
        }

        pub fn swizzle(self: Self, comptime components: []const u8) Vec(components.len, T) {
            comptime var mask: [components.len]u8 = undefined;
            comptime var i: usize = 0;
            inline for (components) |c| {
                switch (c) {
                    'x' => mask[i] = 0,
                    'y' => mask[i] = 1,
                    'z' => mask[i] = 2,
                    'w' => mask[i] = 3,
                    else => @compileError("swizzle: invalid component"),
                }
                i += 1;
            }

            return Vec(components.len, T){
                .values = @shuffle(
                    T,
                    self.values,
                    @as(@Vector(1, T), undefined),
                    mask,
                ),
            };
        }

        pub fn magnitude(self: Self) T {
            comptime var type_info = @typeInfo(T);
            if (type_info == .Int and type_info.Int.signedness == .signed) {
                type_info.Int.signedness = .unsigned;
                return @intCast(std.math.sqrt(
                    @as(
                        @Type(type_info),
                        @bitCast(@reduce(
                            .Add,
                            self.values * self.values,
                        )),
                    ),
                ));
            } else {
                return std.math.sqrt(
                    @reduce(
                        .Add,
                        self.values * self.values,
                    ),
                );
            }
        }

        pub fn normalize(self: Self) Self {
            return Self{
                .values = self.values / @as(@TypeOf(self.values), @splat(self.magnitude())),
            };
        }

        pub fn dot(self: Self, other: Self) T {
            return @reduce(.Add, self.values * other.values);
        }

        pub fn cross(self: Self, other: Self) Self {
            if (n != 3) {
                @compileError("Vector must have three elements for cross() to be defined");
            }

            const self1 = @shuffle(T, self.values, self.values, [3]u8{ 1, 2, 0 });
            const self2 = @shuffle(T, self.values, self.values, [3]u8{ 2, 0, 1 });
            const other1 = @shuffle(T, other.values, other.values, [3]u8{ 2, 0, 1 });
            const other2 = @shuffle(T, other.values, other.values, [3]u8{ 1, 2, 0 });

            return .{
                .values = self1 * other2 - self2 * other1,
            };
        }

        pub fn distance(self: Self, other: Self) T {
            const sub = Self{
                .values = self.values - other.values,
            };
            return sub.magnitude();
        }

        pub fn angle(self: Self, other: Self) T {
            return std.math.acos(self.dot(other) / (self.magnitude() * other.magnitude()));
        }

        pub fn reflect(self: Self, normal: Self) Self {
            const dotProduct = self.dot(normal);
            return Self{
                .values = self.values - (normal.values *
                    @as(@Vector(n, T), @splat(dotProduct)) *
                    @as(@Vector(n, T), @splat(2))),
            };
        }

        pub fn max(self: Self) T {
            return @reduce(.Max, self.values);
        }

        pub fn min(self: Self) T {
            return @reduce(.Min, self.values);
        }

        pub fn sum(self: Self) T {
            return @reduce(.Add, self.values);
        }

        pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try std.fmt.format(writer, "{}", .{value});
        }
    };
}

test "Vec f32" {
    const Vec2 = Vec(2, f32);
    const v = Vec2.init(.{ 1, 2 });
    try std.testing.expectEqual(@as(f32, 3.0), v.sum());
    try std.testing.expectEqual(@as(f32, 1.0), v.x());
    try std.testing.expectEqual(@as(f32, 2.0), v.y());
    const v2 = Vec2.init(.{ 1, 0 });
    try std.testing.expectEqual(@as(f32, 1.0), v2.magnitude());
    try std.testing.expectEqual(@as(f32, 1.0), v2.normalize().magnitude());
    const v3 = Vec2.init(.{ 0, 1 });
    try std.testing.expectEqual(@as(f32, 0), v3.dot(v2));
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi) / 2, v2.angle(v3), 0.001);
    try std.testing.expectEqual(v2, v2.reflect(v3));
}

test "Vec i32" {
    const Vec2 = Vec(2, i32);
    const v = Vec2{ .values = .{ 1, 2 } };
    try std.testing.expectEqual(@as(i32, 3), v.sum());
    try std.testing.expectEqual(@as(i32, 1), v.x());
    try std.testing.expectEqual(@as(i32, 2), v.y());
    const v2 = Vec2{ .values = .{ 1, 0 } };
    try std.testing.expectEqual(@as(i32, 1), v2.magnitude());
    try std.testing.expectEqual(@as(i32, 1), v2.normalize().magnitude());
    const v3 = Vec2{ .values = .{ 0, 1 } };
    try std.testing.expectEqual(@as(i32, 0), v3.dot(v2));
    try std.testing.expectEqual(v2, v2.reflect(v3));
}

test "swizzle" {
    const v = Vec(2, f32).init(.{ 1, 2 });
    try std.testing.expectEqual(@as(f32, 2), v.swizzle("yx").x());
    try std.testing.expectEqual(@as(f32, 1), v.swizzle("yx").y());
    const v2 = Vec(3, f32).init(.{ 1, 2, 3 });
    const v2_expected = Vec(3, f32).init(.{ 2, 3, 1 });
    try std.testing.expectEqual(v2_expected, v2.swizzle("yzx"));
}
