struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,

    padding0: f32,
    CameraPosition: vec3<f32>,

    padding1: f32,
    CameraToWorldMatrix: mat4x4<f32>,

    tonemapmode: f32,
    gammacorrect: f32,
};

struct OutputTextureData {
    staticFrames: f32,
    totalFrames: f32
}

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;

@group(1) @binding(0) var texture: texture_2d<f32>;
@group(1) @binding(1) var image_history: texture_storage_2d<rgba16float, write>;
@group(1) @binding(2) var image_history_read: texture_2d<f32>;

@group(2) @binding(0) var<storage, read> image_history_data: OutputTextureData;

const ACES_a = 2.51;
const ACES_b = 0.03;
const ACES_c = 2.43;
const ACES_d = 0.59;
const ACES_e = 0.14;

fn applyACES(x: vec3<f32>) -> vec3<f32> {
    return clamp((x * (ACES_a * x + ACES_b)) / (x * (ACES_c * x + ACES_d) + ACES_e), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn isNan(num: f32) -> bool {
    return num != num || (bitcast<u32>(num) & 0x7fffffffu) > 0x7f800000u;
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texcoord: vec2f,
};

@fragment 
fn fragmentMain(fsInput: VertexOutput) -> @location(0) vec4f {
    var pixelPosition = vec2<i32>(fsInput.position.xy);

    var pixel = textureLoad(texture, pixelPosition, 0);
    //var pixel = textureLoad(image_albedo_texture_read, pixelPosition, 0);

    //var pixel = imageBuffer[index].noisy_color;
    //var temporalData = temporalBuffer[index];

    if(image_history_data.staticFrames == 0){
        textureStore(image_history, pixelPosition, vec4<f32>(0, 0, 0, 0));
    } else {
        let w = pixel.w;

        let historyPixel = textureLoad(image_history_read, pixelPosition, 0);
        pixel = mix(historyPixel, pixel, clamp(1 / image_history_data.staticFrames, 0.002, 1));

        if(w > 0 && !(isNan(pixel.x) || isNan(pixel.y) || isNan(pixel.z) || isNan(pixel.w))){
            textureStore(image_history, pixelPosition, pixel);
        }

        pixel.w = 1;
    }

    if(inputData.tonemapmode == 1){
        pixel = vec4<f32>(applyACES(pixel.xyz), pixel.w);
    }

    if(inputData.gammacorrect == 1){
        let oldTransparency = pixel.w;
        pixel = pow(pixel, vec4<f32>(1.0 / 2.2));
        pixel.w = oldTransparency;
    }

    // Displaying

    //return vec4<f32>(position.xy / inputData.resolution, 0, 1);
    return pixel;
}