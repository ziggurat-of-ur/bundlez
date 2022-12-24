# bundlez

Utility to create bundled filesystem assets, and a Zig library to quickly load them into your
app at runtime

## Use Case

You are writing a Zig application, and you want to serve up "files" from a tree of 
static assets.

One way to do this is simply ship your app with a directory of assets that need to be installed
on the user's machine.

Problems with this :
- Disk reads at runtime are slow
- Installed assets on a user's disk can get lost / hacked / misplaced / damaged
- Portability issues : standard location / different path naming conventions on different OS's etc
 

## Solution

Bundle the whole assets directory into your Zig app using @embedFile("all-my-files.bundle")

Then at runtime, expand the bundle into a map[string]string

## Zig Version

Currently building with v0.11.dev 

## How to use

Firstly, checkout this project, and build the `bundlez` binary. Copy that binary
into your path.


In your project, do the following things :

- Where you have a directory of assets that you want to make available at runtime,
  simply run `bundlez my-directory-name` to create a bundle file, which will be 
  named `my-directory-name.bundle`

- Either submodule this project, or just simply copy `src/bundle.zig` into your project
  and reference it from there.

- In your code, @embedFile the bundle into your runtime 
```
const assets: []const u8 = @embedFile("my-directory-name.bundle");
```

- When you start your program, pass the emebdded assets to the bundle object,
  and that gives you a virtual filesystem to pull the assets from.

- Call `my_bundle.file(path: []const u8): []const u8` whenever you want to get a slice
  of the data associated with the file.


Another Simple Example :

```
const std = @import("std");
const bundle = @import("bundle.zig");
const assets_data: []const u8 = @embedFile("assets_bundle");

pub fn main() !void {
  var assets_bundle = try bundle.init(assets_data, std.heap.page_allocator);
  defer assets_bundle.deinit();

  // application context, include a reference to the assets bundle in there
  var context = Context.init(assets_bundle, ...);

  // ... do other stuff  
}

// use the bundle in a handler 
pub fn MyFileHandler(context: *Context, req: *Request, resp: *Response) !void {

  try resp.write(try context.bundle.file(req.path));
}
```




## Using the CLI Bundler

From the command line
```
$ bundlez my-directory-name
```

This will create a single new file `my-directory-name.bundle`, that includes all the files in that directory, 
prefixed with a simple index.

## Size Limitaions

Current version has the following limitations on the bundle :

- Max number of files = max(u16)
- Max length of a filename = max(u16)
- Total length of the filename index = max(u32)
- Max size of any file = max(u32)

- Max size of the total bundle = unlimited

## Bundle file format

You dont need to know this to use the library, but its documented here in case you want to extend it, or play around with it.

v1.0 - uncompressed data

------------ Header ------------

Header: [2]u8  "BZ"

NumEntries: u16 LittleEndian

StartOffsetContent: u32 LittleEndian = start offset for all the file contents.  Add this value to each entries start and end offets to get the location in the bundle for the content entry.

------------ Index -------------

for each entry:

LenFilename: u16 LittleEndian

Fliename: [N]u8  where N = length of the filename

StartOffset: u32 LittleEndian = start of the file contents

EndOffset: u32 LittleEndian = end of the file contents


------------ Content ----------

for each entry:

- variable string of bytes making up the Content
- The index contains the pathname, start offset and end offset 
  to slice the contents out of any file from the total payload
- Add the header's 'StartOffsetContent' value to the entry's 
  start/end offset to get the actual offset into the bundle.



