#include "classes/vector3.wgsl"
#include "classes/color.wgsl"
#include "classes/ray.wgsl"

#include "path_trace.wgsl"

fn getTemporalData(
    pixel: vec2<u32>
) -> TemportalData {
    return temporalBuffer[pixel.x + pixel.y * u32(inputData.resolution.x)];
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

    return (inputData.CameraToWorldMatrix * vec4<f32>(cameraX, cameraY, -1, 0)).xyz;
}

fn calculateTemporalData(
    pixel: vec2<u32>,
    traceOutput: Pixel,
    start: vec3<f32>,
    direction: vec3<f32>,
) -> TemportalData {
    var output: TemportalData;

    output.rayDirection = direction;

    return output;
}

fn calculatePixelColor(
    pixel: vec2<u32>
) -> TraceOutput {
    let direction = calculatePixelDirection(pixel);
    let start = inputData.CameraPosition;

    var output: TraceOutput;

    let temporalData = getTemporalData(pixel);
    var traceOutput = RunTracer(direction, start);

    traceOutput.velocity = (temporalData.rayDirection - direction).xy;

    output.pixel = traceOutput;
    output.temporalData = calculateTemporalData(pixel, traceOutput, start, direction);

    return output;
}