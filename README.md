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

Bundle the whole assets directory into your Zig app using @embed("all-my-files.bundle")

Then at runtime, expand the bundle into a map[string]string

## Zig Version

Currently building with v0.11.dev 


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

v1.0 - uncompressed data

------------ Header ------------
Header: [2]u8  "BZ"

NumEntries: u16 LittleEndian
StartOffsetContent: u32 LittleEndian

------------ Index -------------
for each entry:

LenFilename: u16 LittleEndian
Fliename: [N]u8  where N = length of the filename
StartOffset: u32 LittleEndian
EndOffset: u32 LittleEndian

------------ Content ----------
for each entry:

- variable string of bytes making up the Content
- The index contains the pathname, start offset and end offset 
  to slice the contents out of any file from the total payload



