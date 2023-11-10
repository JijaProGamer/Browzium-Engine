struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,
    padding0: f32,
    CameraPosition: vec3<f32>,
    padding1: f32,
    CameraToWorldMatrix: mat4x4<f32>,
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
  return Vector3(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z);
}

fn vector_mul_scalar(t: f32, v: Vector3) -> Vector3 {
   return Vector3(v.x * t, v.y * t, v.z * t);
}

fn vector_div(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x / v2.x, v1.y / v2.y, v1.z / v2.z);
}

fn vector_div_scalar(v: Vector3, t: f32) -> Vector3 {
  return vector_mul_scalar(1.0 / t, v);
}

fn vector_dot(v1: Vector3, v2: Vector3) -> f32 {
  return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

fn vector_cross(v1: Vector3, v2: Vector3) -> Vector3 {
    return Vector3(
        v1.y * v2.z - v1.z * v2.y,
        v1.z * v2.x - v1.x * v2.z,
        v1.x * v2.y - v1.y * v2.x
    );}

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
  origin: vec3<f32>,
  direction: vec3<f32>
};

fn rayAt(r: ray, t: f32) -> vec3<f32> {
  return r.origin + t * r.direction;
}


struct Pixel {
    noisy_color: Color
    //albedo: array<u32, 3>,
}

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


fn rotateVector(direction: vec3<f32>) -> vec3<f32> {
    //return direction;
    return (inputData.CameraToWorldMatrix * vec4f(direction, 0)).xyz;
}

fn calculatePixelDirection(
    pixel: vec2<u32>
) -> vec3<f32> {
    let depth = tan(inputData.fov * (3.14159265358979323846 / 180.0) / 2.0);
    let aspectRatio = inputData.resolution.x / inputData.resolution.y;

    let ndcX = (f32(pixel.x) + 0.5) / inputData.resolution.x;
    let ndcY = (f32(pixel.y) + 0.5) / inputData.resolution.y;

    let screenX = 2 * ndcX - 1;
    let screenY = 1 - 2 * ndcY;

    let cameraX = screenX * aspectRatio * depth;
    let cameraY = screenY * depth;

    let cameraPos = vec3<f32>(cameraX, cameraY, -1);
    //return cameraPos;
    return rotateVector(cameraPos);
}

fn calculatePixelColor(
    pixel: vec2<u32>
) -> Pixel {
    let direction = calculatePixelDirection(pixel);
    let start = inputData.CameraPosition;

    /*let a = 0.5 * (NDC.y + 1.0);
    let White = Color(0.8, 0.8, 0.8);
    let Blue = Color(0.3, 0.5, 0.8);
    let color = color_add(color_mul_scalar((1.0-a), White), color_mul_scalar(a, Blue));

    output.noisy_color.r = color.r;
    output.noisy_color.g = color.g;
    output.noisy_color.b = color.b;*/

    /*output.noisy_color.r = (NDC.x + 1) / 2;
    output.noisy_color.g = (NDC.y + 1) / 2;
    output.noisy_color.b = (NDC.z + 1) / 2;*/

    /*output.noisy_color.r = pow(NDC.x, 1.0 / 2.2);
    output.noisy_color.g = pow(NDC.y, 1.0 / 2.2);
    output.noisy_color.b = pow(NDC.z, 1.0 / 2.2);*/

    let output = RunTracer(direction, start);

    /*output.noisy_color.r = NDC.x;
    output.noisy_color.g = NDC.y;
    output.noisy_color.b = NDC.z;*/

    //output.noisy_color.r = inputData.resolution.x;
    //output.noisy_color.g = inputData.resolution.y;
    //output.noisy_color.b = inputData.fov;

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

    let pixelData = calculatePixelColor(pixel.xy);

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