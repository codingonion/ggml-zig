const std = @import("std");
const c = @cImport({
    @cInclude("ggml/ggml.h");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

pub fn main() !void {
    const params = .{
        .mem_size   = 128*1024*1024,
        .mem_buffer = null,
        .no_alloc   = false,
    };

    const ctx0 = c.ggml_init(params);
    defer c.ggml_free(ctx0);

    {
        const x: [*c]c.struct_ggml_tensor = c.ggml_new_tensor_1d(ctx0, c.GGML_TYPE_F32, 1);

        c.ggml_set_param(ctx0, x);

        const a = c.ggml_new_tensor_1d(ctx0, c.GGML_TYPE_F32, 1);
        const b = c.ggml_mul(ctx0, x, x);
        const f = c.ggml_mul(ctx0, b, a);

        // a*x^2
        // 2*a*x

        c.ggml_print_objects(ctx0);

        const gf = c.ggml_build_forward(f);
        const gb = c.ggml_build_backward(ctx0, @constCast(&gf), false);


        _ = c.ggml_set_f32(x, 2.0);
        _ = c.ggml_set_f32(a, 3.0);

        c.ggml_graph_reset(@constCast(&gf));
        _ = c.ggml_set_f32(f.*.grad, 1.0);

        c.ggml_graph_compute(ctx0, @constCast(&gb));

        std.debug.print("f     = {d:.6}\n", .{c.ggml_get_f32_1d(f, 0)});
        std.debug.print("df/dx = {d:.6}\n", .{c.ggml_get_f32_1d(x.*.grad, 0)});

        try std.testing.expect(c.ggml_get_f32_1d(f, 0)          ==  12.0);
        try std.testing.expect(c.ggml_get_f32_1d(x.*.grad, 0)   ==  12.0);

        _ = c.ggml_set_f32(x, 3.0);

        c.ggml_graph_reset(@constCast(&gf));
        _ = c.ggml_set_f32(f.*.grad, 1.0);

        c.ggml_graph_compute(ctx0, @constCast(&gb));

        std.debug.print("f     = {d:.6}\n", .{c.ggml_get_f32_1d(f, 0)});
        std.debug.print("df/dx = {d:.6}\n", .{c.ggml_get_f32_1d(x.*.grad, 0)});

        try std.testing.expect(c.ggml_get_f32_1d(f, 0)          ==  27.0);
        try std.testing.expect(c.ggml_get_f32_1d(x.*.grad, 0)   ==  18.0);

        c.ggml_graph_dump_dot(&gf, null, "test1-1-forward.dot");
        c.ggml_graph_dump_dot(&gb, &gf,  "test1-1-backward.dot");
    }

    /////////////////////////////////////////////////////////////

    {
        const x1 = c.ggml_new_tensor_1d(ctx0, c.GGML_TYPE_F32, 1);
        const x2 = c.ggml_new_tensor_1d(ctx0, c.GGML_TYPE_F32, 1);
        const x3 = c.ggml_new_tensor_1d(ctx0, c.GGML_TYPE_F32, 1);

        _ = c.ggml_set_f32(x1, 3.0);
        _ = c.ggml_set_f32(x2, 1.0);
        _ = c.ggml_set_f32(x3, 0.0);

        c.ggml_set_param(ctx0, x1);
        c.ggml_set_param(ctx0, x2);

        const y = c.ggml_add(ctx0, c.ggml_mul(ctx0, x1, x1), c.ggml_mul(ctx0, x1, x2));

        const gf = c.ggml_build_forward(y);
        const gb = c.ggml_build_backward(ctx0, @constCast(&gf), false);

        c.ggml_graph_reset(@constCast(&gf));
        _ = c.ggml_set_f32(y.*.grad, 1.0);

        c.ggml_graph_compute(ctx0, @constCast(&gb));

        std.debug.print("y      = {d:.6}\n", .{c.ggml_get_f32_1d(y, 0)});
        std.debug.print("df/dx1 = {d:.6}\n", .{c.ggml_get_f32_1d(x1.*.grad, 0)});
        std.debug.print("df/dx2 = {d:.6}\n", .{c.ggml_get_f32_1d(x2.*.grad, 0)});

        try std.testing.expect(c.ggml_get_f32_1d(y, 0)          ==  12.0);
        try std.testing.expect(c.ggml_get_f32_1d(x1.*.grad, 0)  ==  7.0);
        try std.testing.expect(c.ggml_get_f32_1d(x2.*.grad, 0)  ==  3.0);

        const g1 = x1.*.grad;
        const g2 = x2.*.grad;

        const gbb = c.ggml_build_backward(ctx0, @constCast(&gb), true);

        c.ggml_graph_reset(@constCast(&gb));
        _ = c.ggml_set_f32(g1.*.grad, 1.0);
        _ = c.ggml_set_f32(g2.*.grad, 1.0);

        c.ggml_graph_compute(ctx0, @constCast(&gbb));

        std.debug.print("H * [1, 1] = [ {d:.6} {d:.6} ]\n", .{c.ggml_get_f32_1d(x1.*.grad, 0), c.ggml_get_f32_1d(x2.*.grad, 0)});

        try std.testing.expect(c.ggml_get_f32_1d(x1.*.grad, 0)  ==  3.0);
        try std.testing.expect(c.ggml_get_f32_1d(x2.*.grad, 0)  ==  1.0);

        c.ggml_graph_dump_dot(&gf, null, "test1-2-forward.dot");
        c.ggml_graph_dump_dot(&gb, &gf,  "test1-2-backward.dot");
    }
    
    _ = try std.io.getStdIn().reader().readByte();
}
