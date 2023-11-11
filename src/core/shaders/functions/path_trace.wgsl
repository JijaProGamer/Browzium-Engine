fn hit_triangle(tri: Triangle, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> f32 {
    let edge1 = tri.b - tri.a;
    let edge2 = tri.c - tri.a;
    let h = cross(ray_direction, edge2);
    let a = dot(edge1, h);

    if a > -0.00001 && a < 0.00001 {
        return -1;
    }

    let f = 1.0 / a;
    let s = ray_origin - tri.a;
    let u = f * dot(s, h);

    if u < 0.0 || u > 1.0 {
        return -1;
    }

    let q = cross(s, edge1);
    let v = f * dot(ray_direction, q);

    if v < 0.0 || u + v > 1.0 {
        return -1;
    }

    let t = f * dot(edge2, q);

    if(t < 1e-6){
        return -1;
    }

    return t;
}

fn RunTracer(direction: vec3<f32>, start: vec3<f32>) -> Pixel {
    var output: Pixel;

    /*output.noisy_color.r = direction.x;
    output.noisy_color.g = direction.y;
    output.noisy_color.b = direction.z;*/

    /*let triangle1 = Triangle(
        vec3<f32>(-1.0, -1.0, 5.0),
        vec3<f32>(1.0, -1.0, 5.0),
        vec3<f32>(0.0, 1.0, 5.0),
        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0)
    );

    let triangle2 = Triangle(
        vec3<f32>(-1.0, -1.0, 5.0),
        vec3<f32>(0.0, 1.0, 5.0),
        vec3<f32>(-1.0, 1.0, 5.0),
        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0)
    );

    // First triangle
    if (hit_triangle(triangle1, start, direction) > 0) {
        output.noisy_color.r = 1;
        output.noisy_color.g = 1;
        output.noisy_color.b = 1;
    }

    // Second triangle
    if (hit_triangle(triangle2, start, direction) > 0) {
        output.noisy_color.r = 1;
        output.noisy_color.g = 1;
        output.noisy_color.b = 1;
    }*/

    var hit = false;

    /*for (var i: f32 = 0; i < inputMap.triangle_count; i = i + 1) {
        let currentTriangle = inputMap.triangles[u32(i)];

        if (hit_triangle(currentTriangle, start, direction) > 0) {
            hit = true;
        }
    }*/

    let triangle1 = Triangle(
        vec3<f32>(-1.0, -1.0, 5.0),
        vec3<f32>(1.0, -1.0, 5.0),
        vec3<f32>(0.0, 1.0, 5.0),

        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0)
    );

    let triangle2 = Triangle(
        vec3<f32>(-1.0, 1.0, 1.0),
        vec3<f32>(0.0, 1.0, -1.0),
        vec3<f32>(-1.0, 1.0, 1.0),

        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0),
        vec3<f32>(0.0, 0.0, 0.0)
    );

    if (hit_triangle(triangle1, start, direction) > 0) {
        hit = true;
    }

    if (hit_triangle(triangle2, start, direction) > 0) {
        hit = true;
    }

    if(hit){
        output.noisy_color.r = 1;
        output.noisy_color.g = 1;
        output.noisy_color.b = 1;
    }

    return output;
}
