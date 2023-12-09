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

struct Triangle {
    a: vec3<f32>,
    padding0: f32,
    b: vec3<f32>,
    padding1: f32,
    c: vec3<f32>,
    padding2: f32,

    na: vec3<f32>,
    padding3: f32,
    nb: vec3<f32>,
    padding4: f32,
    nc: vec3<f32>,
    padding5: f32,

    material_index: f32,
    padding6: f32,
    padding7: f32,
    padding8: f32,
};

struct Material {
    color: vec3<f32>,
    padding0: f32,

    transparency: f32,
    index_of_refraction: f32,

    reflectance: f32,
    emittance: f32,
};

struct InputMapData {
    triangle_count: f32,
    padding0: f32,
    padding1: f32,
    padding2: f32,
    triangles: array<Triangle>,
};

struct Pixel {
    noisy_color: vec4<f32>,
    albedo: vec3<f32>,
    normal: vec3<f32>,
    velocity: vec2<f32>,
    depth: f32,
    //depth: f32,
    //albedo: array<u32, 3>,
}

struct TemportalData {
    rayDirection: vec3<f32>,
}

struct TraceOutput {
    pixel: Pixel,
    temporalData: TemportalData,
}

struct TreePart {
    center: vec3<f32>,
    padding0: f32,

    halfSize: f32,
    children: array<f32, 8>,
    triangles: array<f32, 16>,
    padding1: f32,

    padding2: f32,
    padding3: f32
}

struct OutputTextureData {
    staticFrames: f32,
    totalFrames: f32
}

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;

@group(1) @binding(0) var<storage, read> inputMap: InputMapData;
@group(1) @binding(1) var<storage, read> inputMaterials: array<Material>;
@group(1) @binding(2) var<storage, read> inputTreeParts: array<TreePart>;


@group(2) @binding(0) var image_color_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(1) var image_normal_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(2) var image_depth_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(3) var image_albedo_texture: texture_storage_2d<rgba16float, write>;

@group(3) @binding(0) var<storage, read> image_history_data: OutputTextureData;

#include "functions/calculate_pixel.wgsl"

@compute @workgroup_size(16, 16, 1) 
fn computeMain(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    if (f32(global_invocation_id.x) >= inputData.resolution.x || f32(global_invocation_id.y) >= inputData.resolution.y) {
        return;
    }

    let index = global_invocation_id.x + global_invocation_id.y * u32(inputData.resolution.x);
    let pixelData = calculatePixelColor(vec2<f32>(global_invocation_id.xy));

    //imageBuffer[index] = pixelData.pixel;
    //temporalBuffer[index] = pixelData.temporalData;

    textureStore(image_color_texture, global_invocation_id.xy, pixelData.pixel.noisy_color);
    textureStore(image_albedo_texture, global_invocation_id.xy, vec4<f32>(pixelData.pixel.albedo, 0));
    textureStore(image_normal_texture, global_invocation_id.xy, vec4<f32>(pixelData.pixel.normal, 0));
    textureStore(image_depth_texture, global_invocation_id.xy, vec4<f32>(pixelData.pixel.depth, 0, 0, 0));
}