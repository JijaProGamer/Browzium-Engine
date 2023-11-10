fn hit_sphere(center: vec3<f32>, radius: f32, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> bool {
    let oc = ray_origin - center;
    let a = dot(ray_direction, ray_direction);
    let b = 2.0 * dot(oc, ray_direction);
    let c = dot(oc, oc) - radius * radius;
    let discriminant = b * b - 4.0 * a * c;

    if discriminant >= 0.0 {
        let t = (-b - sqrt(discriminant)) / (2.0 * a);

        return t >= 0.0;
    }

    return false;}

fn RunTracer(direction: vec3<f32>, start: vec3<f32>) -> Pixel {
    var output: Pixel;

    /*output.noisy_color.r = direction.x;
    output.noisy_color.g = direction.y;
    output.noisy_color.b = direction.z;*/

    if (hit_sphere(vec3<f32>(0.0, 0.0, -5.0), 3, start, direction)) {
        output.noisy_color.r = 1;
        output.noisy_color.g = 1;
        output.noisy_color.b = 1;
    }

    return output;
}
