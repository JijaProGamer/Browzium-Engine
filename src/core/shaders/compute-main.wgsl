struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,
    //cameraPosition: Vector3,
    //cameraRotation: Vector3,
    cameraPosition: vec3<f32>,
    cameraRotation: vec3<f32>,
};

struct InputMapData {
    triangle_count: u32,
    triangles: array<u32>,
};

@group(0) @binding(0) var<storage, read_write> noise_image_buffer: array<f32>;
@group(0) @binding(1) var<storage, read> inputData: InputGlobalData;
@group(0) @binding(2) var<storage, read> inputMap: InputMapData;

#include "functions/calculate_pixel.wgsl"

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