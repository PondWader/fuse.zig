# fuse.zig

Zig FUSE daemon library.

Create and mount userspace file systems in Linux with Zig. Learn more about FUSE on [the Linux kernel website](https://www.kernel.org/doc/html/next/filesystems/fuse.html).

### Notes

- This library is only targetted at Linux for now but I'm open to contributions for other platforms.

### Examples

[hello.zig](./examples/hello.zig) - a simple "Hello world" file system with read and write examples.

To run an example, clone this repository and run `zig build example-<name>` e.g. `zig build example-hello`.
