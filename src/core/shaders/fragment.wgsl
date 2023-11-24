fn pixelToIndex(position: vec2<f32>) -> u32 {
    return u32(position.x + position.y * inputData.resolution.x);
}

const FXAA_SPAN_MAX = 8.0;
const FXAA_REDUCE_MUL = 1.0 / 8.0;
const FXAA_REDUCE_MIN = 1.0 / 128.0;
const luma = vec3<f32>(0.299, 0.587, 0.114);

fn shouldApplyFXAA(color1: vec3<f32>, color2: vec3<f32>) -> bool {
    let luma = vec3<f32>(0.299, 0.587, 0.114);
    let luma1 = dot(color1, luma);
    let luma2 = dot(color2, luma);
    let lumaMin = min(luma1, luma2);
    let lumaMax = max(luma1, luma2);
    
    let lumaRange = lumaMax - lumaMin;

    return (lumaRange > 0.0) && (lumaRange > FXAA_REDUCE_MIN);
}

fn applyFXAA(centerColor: vec3<f32>, fragCoord: vec2<f32>) -> vec3<f32> {
    let lumaCenter = dot(centerColor, luma);

    let lumaTop = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, -1.0))].noisy_color, luma);
    let lumaBottom = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, 1.0))].noisy_color, luma);
    let lumaLeft = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 0.0))].noisy_color, luma);
    let lumaRight = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 0.0))].noisy_color, luma);

    let lumaMax = max(max(max(abs(lumaCenter - lumaTop), abs(lumaCenter - lumaBottom)),
                         abs(lumaCenter - lumaLeft)),
                     abs(lumaCenter - lumaRight));

    let blendFactor = clamp(1.0 / ((lumaMax * lumaMax) + 0.0001), 0.0, 1.0);

    return mix(centerColor, (
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, 1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 0.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 0.0))].noisy_color
    ) * 0.25, blendFactor);
}

/*
fn applyFXAA(centerColor: vec3<f32>, fragCoord: vec2<f32>) -> vec3<f32> {
    let lumaCenter = dot(centerColor, luma);
    var lumaMax = 0.0;

    for (var x: f32 = -1.0; x <= 1.0; x += 1.0) {
        for (var y: f32 = -1.0; y <= 1.0; y += 1.0) {
            if (x == 0.0 && y == 0.0) {
                continue;
            }

            let lumaNeighbor = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(x, y))].noisy_color, luma);
            lumaMax = max(lumaMax, abs(lumaCenter - lumaNeighbor));
        }
    }

    let blendFactor = clamp(1.0 / ((lumaMax * lumaMax) + 0.0001), 0.0, 1.0);

    return mix(centerColor, (
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, 1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 0.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 0.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 1.0))].noisy_color
    ) * 0.125, blendFactor);
}
*/

@fragment 
fn fragmentMain(@builtin(position) position: vec4<f32>) -> @location(0) vec4f {
    // Indexing

    var pixelPosition = position.xy;

    if(pixelPosition.x < inputData.resolution.x / 2){
        pixelPosition.x += inputData.resolution.x / 2;
    } else {
        pixelPosition.x -= inputData.resolution.x / 2;
    }

    let index = pixelToIndex(pixelPosition);
    var pixel = imageBuffer[index].noisy_color;

    if(inputData.antialias == 1){
        pixel = applyFXAA(pixel, pixelPosition);
    }

    if(inputData.gammacorrect == 1){
        pixel = pow(pixel, vec3<f32>(1.0 / 2.2));
    }

    // Displaying

    return vec4<f32>(pixel.r, pixel.g, pixel.b, 1);
}