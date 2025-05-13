const std = @import("std");

const print = std.debug.print;

const FileEntry = struct {
    path: []const u8,
    size: u64
};

pub fn main() !void {
    var dir = try std.fs.cwd().openDir(".", .{.iterate=true});
    defer dir.close();

    //var iter = dir.iterate();

    //while (try iter.next()) |entry| {
    //    print("{s}\n", .{entry.name});
    //}

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var file_list = std.ArrayList(FileEntry).init(alloc);

    defer {
        for (file_list.items) |file| {
            alloc.free(file.path);
        }
        file_list.deinit();
    }

    var walker = try dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        //const type_str = switch (entry.kind) {
        //    .file => "f",
        //    .directory => "d",
        //    else => "u"
        //};
        //print("{s} {s}\n", .{entry.path, type_str});

        //print("{}\n", .{@TypeOf(entry)});
        if (entry.kind == .file) {
            //if (std.mem.endsWith(u8, entry.path, ".zig")) {
                const file = try dir.openFile(entry.path, .{.mode = .read_only});
                defer file.close();
                const stat = try file.stat();
                //print("{s} {}\n", .{entry.path, stat.size});
                const path_copy = try alloc.dupe(u8, entry.path);
                try file_list.append(.{.path=path_copy, .size=stat.size});
            //}
        }
    }

    std.mem.sort(
        FileEntry,
        file_list.items,
        {}, // context, not needed here
        struct {
            fn lessThan(_: void, lhs: FileEntry, rhs: FileEntry) bool {
                return lhs.size > rhs.size;
            }
        }.lessThan,
    );

    const stdout = std.io.getStdOut().writer();

    for (file_list.items) |file| {
        const units = [_]u64 {
            1024 * 1024 * 1024, // GB
            1024 * 1024, // MB
            1024, // KB
        };
        const unit_strs = [_][]const u8 {
            "GB",
            "MB",
            "KB"
        };
        const size_bytes = file.size;
        const formatted_size: struct{value: f64, unit: []const u8} = for (units, unit_strs) |unit_size, unit_name| {
            const whole_units = size_bytes / unit_size;
            if (whole_units > 0) {
                const remainder_bytes = size_bytes % unit_size;
                const decimal_portion: f64 = @as(f64, @floatFromInt(remainder_bytes)) / @as(f64, @floatFromInt(unit_size));
                break .{
                    .value = @as(f64, @floatFromInt(whole_units)) + decimal_portion,
                    .unit = unit_name
                };
            }
        } else .{
            .value = @as(f64, @floatFromInt(size_bytes)),
            .unit = "bytes"
        };

        //print("{s: <50} {: >50} bytes\n", .{file.path, file.size});
        if (std.mem.eql(u8, formatted_size.unit, "bytes")) {
            _ = try stdout.print("{s: <50} {d:.0} {s}\n", .{ file.path, formatted_size.value, formatted_size.unit });
        } else {
            _ = try stdout.print("{s: <50} {d:.3} {s}\n", .{ file.path, formatted_size.value, formatted_size.unit });
        }
    }
}
