#include "classes/vector3.wgsl"
#include "classes/color.wgsl"
#include "classes/ray.wgsl"

#include "path_trace.wgsl"

/*fn getTemporalData(
    pixel: vec2<f32>
) -> TemportalData {
    return temporalBuffer[u32(pixel.x + pixel.y * inputData.resolution.x)];
}*/

fn calculatePixelDirection(
    pixel: vec2<f32>
) -> vec3<f32> {
    let depth = tan(inputData.fov * (3.14159265358979323846 / 180.0) / 2.0);
    let aspectRatio = inputData.resolution.x / inputData.resolution.y;

    let ndcX = (f32(pixel.x) + 0.5) / inputData.resolution.x;
    let ndcY = (f32(pixel.y) + 0.5) / inputData.resolution.y;

    let screenX = 2 * ndcX - 1;
    let screenY = 1 - 2 * ndcY;

    let cameraX = screenX * aspectRatio * depth;
    let cameraY = screenY * depth;

    return (inputData.CameraToWorldMatrix * vec4<f32>(cameraX, cameraY, -1, 1)).xyz;
}

struct DOFOutput
{
    start: vec3<f32>,
    direction: vec3<f32>,
    pixelHash: f32,
}

fn applyDOF(
    direction: vec3<f32>,
    pixel: vec2<f32>,
    pixelHash: f32,
) -> DOFOutput {
    var output: DOFOutput;
    let focalPoint = inputData.CameraPosition + direction * inputData.focalLength;
    let randomAperture = random2Vec2(pixelHash, pixel);
    let apertureShift = randomAperture.output * inputData.apertureSize;

    output.start = inputData.CameraPosition + vec3<f32>(apertureShift.x, apertureShift.y, 0.0);
    output.direction = normalize(focalPoint - output.start);
    output.pixelHash = randomAperture.seed;

    return output;
}

fn calculateTemporalData(
    pixel: vec2<f32>,
    traceOutput: Pixel,
    start: vec3<f32>,
    direction: vec3<f32>,
) -> TemportalData {
    var output: TemportalData;

    output.rayDirection = direction;

    return output;
}

fn calculatePixelColor(
    pixel: vec2<f32>,
    initialPixelHash: f32, 
) -> TraceOutput {
    //var pixelHash = randomVec2(initialPixelHash, pixel);
    var pixelModifier = random2Vec2(/*pixelHash*/initialPixelHash, pixel);

    var realPixel = pixel + (pixelModifier.output + vec2<f32>(1, 1)) / 2;
    //let DOF = applyDOF(calculatePixelDirection(realPixel), realPixel, pixelModifier.seed);
    let DOF = applyDOF(calculatePixelDirection(realPixel), realPixel, initialPixelHash);
    
    let direction = DOF.direction;
    let start = DOF.start;

    var output: TraceOutput;

    //let temporalData = getTemporalData(realPixel);
    var traceOutput = RunTracer(direction, start, DOF.pixelHash);

    //traceOutput.velocity = (temporalData.rayDirection - direction).xy;

    output.pixel = traceOutput;
    output.seed = traceOutput.seed;
    //output.temporalData = calculateTemporalData(realPixel, traceOutput, start, direction);

    return output;
}