const std = @import("std");

const Self = @This();

allocator: std.mem.Allocator = undefined,
map: std.StringArrayHashMap([]const u8) = undefined,

pub fn init(contents: []const u8, allocator: std.mem.Allocator) !Self {
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

    try self.map.ensureTotalCapacity(num_entries);

    var i: u16 = 0;
    var path_start: usize = 8;
    while (i < num_entries) : (i += 1) {
        var name_len = try r.readIntLittle(u16);
        path_start += 2;

        // dont need to read the key or allocate room for it, since it already
        // exists in our content buffe
        try r.skipBytes(name_len, .{});
        var path = contents[path_start .. path_start + name_len];
        path_start += name_len;

        var start_offset = try r.readIntLittle(u32) + start_content;
        var end_offset = try r.readIntLittle(u32) + start_content;
        path_start += 8; // advance 8 bytes due to the 2x u32s

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
    // dont need to free the keys, they are part of the content buffer
    // for (self.map.keys()) |key| {
    // self.allocator.free(key);
    // }
    self.map.deinit();
}

pub fn file(self: Self, path: []const u8) ?[]const u8 {
    return self.map.get(path);
}
