const std = @import("std");

const Self = @This();

allocator: std.mem.Allocator = undefined,
map: std.StringArrayHashMap([]const u8) = undefined,

pub fn init(contents: []u8, allocator: std.mem.Allocator) !Self {
    try std.testing.expectStringStartsWith(contents, "BZ");

    var self = Self{
        .allocator = allocator,
        .map = std.StringArrayHashMap([]const u8).init(allocator),
    };

    var fbs = std.io.fixedBufferStream(contents);
    var r = fbs.reader();
    try std.testing.expectEqual(try r.readByte(), 'B');
    try std.testing.expectEqual(try r.readByte(), 'Z');
    var num_entries = try r.readIntLittle(u16);
    var start_content = try r.readIntLittle(u32);

    var i: u16 = 0;
    while (i < num_entries) : (i += 1) {
        var name_len = try r.readIntLittle(u16);

        var path = try self.allocator.alloc(u8, name_len);
        _ = try r.read(path);

        var start_offset = try r.readIntLittle(u32) + start_content;
        var end_offset = try r.readIntLittle(u32) + start_content;

        try self.map.put(path, contents[start_offset..end_offset]);
    }

    return self;
}

fn readString(in_stream: anytype, allocator: std.mem.Allocator) ![]u8 {
    const len: u8 = try in_stream.readByte();
    var buffer: []u8 = try allocator.alloc(u8, len);
    const bytes_read = try in_stream.read(buffer);
    std.debug.assert(bytes_read == len);
    return buffer;
}

pub fn deinit(self: *Self) void {
    for (self.map.keys()) |key| {
        self.allocator.free(key);
    }
    self.map.deinit();
}

pub fn file(self: Self, path: []const u8) ?[]const u8 {
    return self.map.get(path);
}
