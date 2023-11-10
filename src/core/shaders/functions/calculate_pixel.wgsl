#include "classes/vector3.wgsl"
#include "classes/color.wgsl"
#include "classes/ray.wgsl"

struct Pixel {
    noisy_color: Color
    //albedo: array<u32, 3>,
}

#include "path_trace.wgsl"

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