const std = @import("std");
const bundler = @import("bundler.zig");
const bundle = @import("bundle.zig");

const usage =
    "USAGE: bundlez dirname\n" ++
    "\n" ++
    "Expects dirname to be a directory.\n" ++
    "Will create a file dirname.bundle which contains\n" ++
    "the contents of the directory, plus an index.\n";

const Errors = error{ InvalidDirectory, TestFail };

pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();

    // parse params
    _ = args.skip();
    const dirname = args.next() orelse {
        std.debug.print(usage, .{});
        return Errors.InvalidDirectory;
    };
    std.log.debug("bundlez {s}", .{dirname[0..]});

    try bundler.make(dirname[0..], std.heap.page_allocator);
}

test "bundle test" {
    // delete the bundle if it exists
    std.fs.cwd().deleteFile("testdata.bundle") catch {};

    // create a bundle from the testdata
    bundler.make("testdata", std.testing.allocator) catch |err| {
        std.debug.print("Error running bundler ?: {}\n", .{err});
    };

    // load the bundle !
    var file = try std.fs.cwd().openFile("testdata.bundle", .{});
    var stat = try file.stat();
    var contents = try file.readToEndAlloc(std.testing.allocator, stat.size);
    defer std.testing.allocator.free(contents);

    try std.testing.expectStringStartsWith(contents, "BZ");

    // decode the bundle
    var b = try bundle.init(contents, std.testing.allocator);
    defer b.deinit();

    // try a few random files now
    var index_html = b.file("index.html") orelse return Errors.TestFail;
    std.debug.print("index.html:\n{s}\n", .{index_html});

    var stuff = b.file("dir2/dir22/stuff.html") orelse return Errors.TestFail;
    std.debug.print("stuff:\n{s}\n", .{stuff});

    // compare this to the contents of the actual file

    // clean up the testdata.bundle artifact
    std.fs.cwd().deleteFile("testdata.bundle") catch |err| {
        std.log.info("Error cleaning up file testdata.bundle: {}", .{err});
    };
}
