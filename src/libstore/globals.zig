const std = @import("std");

pub fn getDefaultSystemFeatures() callconv(.C) ?[*:null]const ?[*:0]const u8 {
    var list = std.ArrayList(?[*:0]const u8).init(std.heap.c_allocator);
    defer list.deinit();

    const pgsize = std.heap.pageSize();

    if (pgsize == std.heap.page_size_max) {
        list.append(std.fmt.allocPrintZ(std.heap.c_allocator, "pages-{d}k", .{pgsize / 1024}) catch return null) catch return null;
    } else {
        var i = pgsize;
        while (i < std.heap.page_size_max) : (i *= 2) {
            list.append(std.fmt.allocPrintZ(std.heap.c_allocator, "pages-{d}k", .{i / 1024}) catch return null) catch return null;
        }
    }

    return list.toOwnedSliceSentinel(null) catch return null;
}

comptime {
    @export(&getDefaultSystemFeatures, .{ .name = "nix_libstore_get_default_system_features" });
}
