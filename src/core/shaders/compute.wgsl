struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,
};

struct InputMapData {
    triangle_count: u32,
    triangles: array<u32>,
};

@group(0) @binding(0) var<storage, read_write> noise_image_buffer: array<f32>;
@group(0) @binding(1) var<storage, read> inputData: InputGlobalData;
@group(0) @binding(2) var<storage, read> inputMap: InputMapData;

struct Vector3 {
  x: f32,
  y: f32,
  z: f32,
};

fn vector_neg(v: Vector3) -> Vector3 {
  return Vector3(-v.x, -v.y, -v.z);
}

fn vector_add(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z);
}

fn vector_mul(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x * v2.x, v1.y * v2.y, v1.z * v2.z);
}

fn vector_length(v: Vector3) -> f32 {
  return sqrt(vector_length_squared(v));
}

fn vector_length_squared(v: Vector3) -> f32 {
  return vector_dot(v, v);
}

fn vector_sub(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z);
}

fn vector_mul_scalar(t: f32, v: Vector3) -> Vector3 {
   return Vector3(v.x * t, v.y * t, v.z * t);
}

fn vector_div(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x * v2.x, v1.y * v2.y, v1.z * v2.z);
}

fn vector_div_scalar(v: Vector3, t: f32) -> Vector3 {
  return vector_mul_scalar(1.0 / t, v);
}

fn vector_dot(v1: Vector3, v2: Vector3) -> f32 {
  return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

fn vector_cross(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.y * v2.z - v1.z * v2.y, v1.z * v2.z - v1.x * v2.z, v1.x * v2.y - v1.y * v2.z);
}

fn unit_vector(v: Vector3) -> Vector3 {
  return vector_div_scalar(v, vector_length(v));
}
struct Color {
  r: f32,
  g: f32,
  b: f32,
};

fn color_neg(v: Color) -> Color {
  return Color(-v.r, -v.g, -v.b);
}

fn color_add(v1: Color, v2: Color) -> Color {
  return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b);
}

fn color_mul(v1: Color, v2: Color) -> Color {
  return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
}

fn color_length(v: Color) -> f32 {
  return sqrt(color_length_squared(v));
}

fn color_length_squared(v: Color) -> f32 {
  return color_dot(v, v);
}

fn color_sub(v1: Color, v2: Color) -> Color {
  return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b);
}

fn color_mul_scalar(t: f32, v: Color) -> Color {
   return Color(v.r * t, v.g * t, v.b * t);
}

fn color_div(v1: Color, v2: Color) -> Color {
  return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
}

fn color_div_scalar(v: Color, t: f32) -> Color {
  return color_mul_scalar(1.0 / t, v);
}

fn color_dot(v1: Color, v2: Color) -> f32 {
  return v1.r * v2.r + v1.g * v2.g + v1.b * v2.b;
}

fn color_cross(v1: Color, v2: Color) -> Color {
  return Color(v1.g * v2.b - v1.b * v2.g, v1.b * v2.b - v1.r * v2.b, v1.r * v2.g - v1.g * v2.b);
}

fn unit_color(v: Color) -> Color {
  return color_div_scalar(v, color_length(v));
}
struct ray {
  origin: Vector3,
  direction: Vector3
};

fn rayAt(r: ray, t: f32) -> Vector3 {
  return vector_add(r.origin, vector_mul_scalar(t, r.direction));
}


struct Pixel {
    noisy_color: Color
    //albedo: array<u32, 3>,
}

fn calculateNDCPos(
    pixel: vec2<u32>
) -> Vector3 {
    let fovRadians = inputData.fov * (3.14159265358979323846 / 180.0);
    let aspectRatio = inputData.resolution.x / inputData.resolution.y;

    let d = 1.0 / f32(tan(fovRadians / 2.0));

    let Px = f32(pixel.x) + 0.5;
    let Py = f32(pixel.y) + 0.5;

    let rayDirX = aspectRatio * (2.0 * Px / f32(inputData.resolution.x) - 1.0);
    let rayDirY = 1.0 - (2.0 * Py / f32(inputData.resolution.y));

    return Vector3(rayDirX, rayDirY, d);
}

fn calculatePixelColor(
    pixel: vec2<u32>
) -> Pixel {
    var output: Pixel;
    let NDC = calculateNDCPos(pixel);

    /*output.noisy_color.r = NDC.x + 0.5;
    output.noisy_color.g = NDC.y + 0.5;
    output.noisy_color.b = 0.5;*/

    /*let a = 0.5 * (unit_vector(NDC).y + 1.0);
    let White = Color(1, 1, 1);
    let Blue = Color(0.5, 0.7, 1);
    let color = color_add(color_mul_scalar((1.0-a), White), color_mul_scalar(a, Blue));

    output.noisy_color.r = color.r;
    output.noisy_color.g = color.g;
    output.noisy_color.b = color.b;*/

    output.noisy_color.r = (NDC.x + 1) / 2;
    output.noisy_color.g = (NDC.y + 1) / 2;

    return output;
}

fn run(
    pixel: vec3<u32>,
    index: u32
){
    let imageSize = u32(inputData.resolution.x * inputData.resolution.y);

    let noisyIndex = index * 3;
    let albedoIndex = (index + imageSize) * 3;
    let normalIndex = (index + imageSize * 2) * 3;
    let firstBounceNormalIndex = (index + imageSize * 3) * 3;

    let pixelData = calculatePixelColor(vec2(pixel.x, pixel.y));

    noise_image_buffer[noisyIndex + 0] = pixelData.noisy_color.r;
    noise_image_buffer[noisyIndex + 1] = pixelData.noisy_color.g;
    noise_image_buffer[noisyIndex + 2] = pixelData.noisy_color.b;
}

@compute @workgroup_size(8, 8, 1) 
fn main(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    if (f32(global_invocation_id.x) >= inputData.resolution.x || f32(global_invocation_id.y) >= inputData.resolution.y) {
        return;
    }

    let index = global_invocation_id.x + global_invocation_id.y * u32(inputData.resolution.x);
    run(global_invocation_id, index);
}