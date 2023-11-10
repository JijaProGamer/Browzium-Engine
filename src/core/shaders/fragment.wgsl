struct InputData {
    resolution: vec2<f32>,
    padding0: f32,
};

struct Pixel {
    r: f32,
    g: f32,
    b: f32
}

@group(0) @binding(0) var<storage, read> inputData: InputData;
@group(0) @binding(1) var<storage, read> image_buffer: array<Pixel>;
    
@fragment 
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4f {
    var pixelPosition = position.xy;
    pixelPosition /= vec2<f32>(2, 2);

    let index = u32(pixelPosition.x + pixelPosition.y * inputData.resolution.x);
    let pixel = image_buffer[index];

    return vec4<f32>(pixel.r, pixel.g, pixel.b, 1);
    //return vec4f(pixelPosition / inputData.resolution, 0, 1);
}