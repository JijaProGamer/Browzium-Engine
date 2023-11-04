#include "classes/vector3.wgsl"
#include "classes/color.wgsl"
#include "classes/ray.wgsl"

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

    let viewDir = unit_vector(vector_sub(inputData.cameraRotation, inputData.cameraPosition));

    let rayDir = Vector3(rayDirX, rayDirY, d);
    let NDCPos = cameraPos + rayDir * viewDir;

    return NDCPos;
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