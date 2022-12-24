const std = @import("std");

const Self = @This();

var filename_buffer: [1024]u8 = undefined;
const num_entries_offset = 0x02;
const start_content_offset = 0x04;

num_entries: u16 = 0,
current_offset: u32 = 0,
total_bytes: u32 = 0,
start_content: u32 = 0,
alloc: std.mem.Allocator = undefined,

/// make will create a bundle from the given path
/// output file will be path.bundle
pub fn make(path: []const u8, allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var self = Self{ .num_entries = 0, .current_offset = 0, .total_bytes = 0, .start_content = 0, .alloc = arena.allocator() };

    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();

    var outfile = try std.fs.cwd().createFile(try std.fmt.bufPrint(&filename_buffer, "{s}.bundle", .{path}), .{});
    defer outfile.close();

    var w = outfile.writer();

    // Stamp the header as a BundleZ file
    // may introduce other variants later on - such as ZB for compressed bundle for example
    try w.writeAll("BZ");
    try w.writeIntLittle(u16, 0); // will come back and stamp the correct value later
    try w.writeIntLittle(u32, 0); // will come back and stamp the correct value later

    try self.createIndex("", dir, w);
    std.log.debug("Computed index from {s} with {d} entries and total bytes {d}", .{ path, self.num_entries, self.total_bytes });

    self.start_content = @intCast(u32, try outfile.getEndPos());
    try outfile.seekTo(num_entries_offset);
    try w.writeIntLittle(u16, self.num_entries);
    try w.writeIntLittle(u32, self.start_content);
    try outfile.seekFromEnd(0);

    try self.createContent(dir, w);
    std.log.debug("Content complete", .{});
}

fn createIndex(self: *Self, path: []u8, dir: std.fs.Dir, w: anytype) !void {
    var new_path_buffer: [1024]u8 = undefined;
    var new_path: []u8 = undefined;
    var iter_dir = try dir.openIterableDir(".", .{});
    var iter = iter_dir.iterate();
    while (try iter.next()) |entry| {
        if (path.len > 0) {
            new_path = try std.fmt.bufPrint(&new_path_buffer, "{s}/{s}", .{ path, entry.name });
        } else {
            new_path = try std.fmt.bufPrint(&new_path_buffer, "{s}", .{entry.name});
        }
        switch (entry.kind) {
            .File => {
                var file = try dir.openFile(entry.name, .{});
                var stat = try file.stat();
                var new_offset: u32 = self.current_offset + @intCast(u32, stat.size);
                std.log.debug("{s}: {d} bytes From [{d}-{d}]", .{ new_path, stat.size, self.current_offset, new_offset });

                try w.writeIntLittle(u16, @intCast(u16, new_path.len));
                try w.writeAll(new_path);
                try w.writeIntLittle(u32, self.current_offset);
                try w.writeIntLittle(u32, new_offset);
                self.current_offset = new_offset;
                self.num_entries += 1;
            },
            .Directory => {
                std.log.debug("  diving into subdir {s} ...", .{new_path});
                var sub_dir = try dir.openDir(entry.name, .{});
                defer sub_dir.close();

                try self.createIndex(new_path, sub_dir, w);
            },
            else => {
                std.log.debug("ignore {s} of type {}", .{ entry.name, entry.kind });
            },
        }
    }
}

fn createContent(self: *Self, dir: std.fs.Dir, w: anytype) !void {
    var iter_dir = try dir.openIterableDir(".", .{});
    var iter = iter_dir.iterate();

    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .File => {
                var file = try dir.openFile(entry.name, .{});
                var stat = try file.stat();

                try (w.writeAll(try file.reader().readAllAlloc(self.alloc, stat.size)));
                file.close();
            },
            .Directory => {
                var sub_dir = try dir.openDir(entry.name, .{});
                defer sub_dir.close();

                try self.createContent(sub_dir, w);
            },
            else => {},
        }
    }
}
