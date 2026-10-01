const std = @import("std");

pub const ArrowSchema = extern struct {
    format: [*c]const u8,
    name: [*c]const u8,
    metadata: [*c]const u8,
    flags: i64,
    n_children: i64,
    children: [*c][*c]ArrowSchema,
    dictionary: [*c]ArrowSchema,
    release: ?*const fn (*ArrowSchema) callconv(.c) void,
    private_data: ?*anyopaque,
};

pub const ArrowArray = extern struct {
    length: i64,
    null_count: i64,
    offset: i64,
    n_buffers: i64,
    n_children: i64,
    buffers: [*c]const ?*const anyopaque,
    children: [*c][*c]ArrowArray,
    dictionary: [*c]ArrowArray,
    release: ?*const fn (*ArrowArray) callconv(.c) void,
    private_data: ?*anyopaque,
};

pub const ArrowArrayStream = extern struct {
    get_schema: ?*const fn (*ArrowArrayStream, *ArrowSchema) callconv(.c) c_int,
    get_next: ?*const fn (*ArrowArrayStream, *ArrowArray) callconv(.c) c_int,
    get_last_error: ?*const fn (*ArrowArrayStream) callconv(.c) [*c]const u8,
    release: ?*const fn (*ArrowArrayStream) callconv(.c) void,
    private_data: ?*anyopaque,
};
export fn array_len(arr_ptr: *ArrowArray, arr_schema_ptr: *ArrowSchema) callconv(.c) c_int {
    const arr = asFloat64Slice(arr_ptr, arr_schema_ptr) catch {
        return -1;
    };
    return @as(i32, @intCast(arr.len));
}

pub fn asFloat64Slice(array: *ArrowArray, schema: *ArrowSchema) ![]const f64 {
    // Check format
    const fmt = std.mem.span(schema.format);
    if (!std.mem.eql(u8, fmt, "g")) return error.WrongFormat;

    if (array.null_count != 0) return error.HasNulls;

    // Float64 arrays have 2 buffers: [0] = validity bitmap, [1] = data
    if (array.n_buffers < 2) return error.NullBuffer;
    const raw_ptr = array.buffers[1] orelse return error.NullBuffer;

    const length: usize = @intCast(array.length);
    const offset: usize = @intCast(array.offset);
    const data: [*]const f64 = @ptrCast(@alignCast(raw_ptr));

    return data[offset..][0..length];
}

export fn stream_len(stream: *ArrowArrayStream) callconv(.c) i64 {
    var schema: ArrowSchema = undefined;
    if (stream.get_schema.?(stream, &schema) != 0) return -1;
    defer schema.release.?(&schema);

    var total_rows: i64 = 0;
    while (true) {
        var batch: ArrowArray = undefined;
        if (stream.get_next.?(stream, &batch) != 0) return -1;
        if (batch.release == null) break; // end of stream
        defer batch.release.?(&batch);

        total_rows += batch.length;
    }
    return total_rows;
}
