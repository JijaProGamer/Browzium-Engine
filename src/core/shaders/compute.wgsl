struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,
    focalLength: f32,

    CameraPosition: vec3<f32>,
    apertureSize: f32,

    CameraToWorldMatrix: mat4x4<f32>,

    tonemapmode: f32,
    gammacorrect: f32,
};

struct Triangle {
    a: vec3<f32>,
    material_index: f32,
    b: vec3<f32>,
    object_id: f32,
    c: vec3<f32>,
    padding0: f32,

    na: vec3<f32>,
    padding1: f32,
    nb: vec3<f32>,
    padding2: f32,
    nc: vec3<f32>,
    padding3: f32,

    uva: vec2<f32>,
    uvb: vec2<f32>,
    uvc: vec2<f32>,

    padding4: f32,
    padding5: f32,
};

struct Material {
    color: vec3<f32>,
    texture_layer: f32,
    
    specular_color: vec3<f32>,
    transparency: f32,

    diffuse_atlas_start: vec2<f32>,
    diffuse_atlas_extend: vec2<f32>,
    
    index_of_refraction: f32,
    reflectance: f32,
    emittance: f32,
    roughness: f32,
};

struct InputMapData {
    triangle_count: f32,
    padding0: f32,
    padding1: f32,
    padding2: f32,
    triangles: array<Triangle>,
};

struct InputLightData {
    triangle_count: f32,
    triangles: array<f32>,
};

struct Pixel {
    noisy_color: vec4<f32>,
    albedo: vec3<f32>,
    normal: vec3<f32>,
    velocity: vec2<f32>,
    depth: f32,
    object_id: f32,
    intersection: vec3<f32>,
    seed: f32,
}

struct TemportalData {
    rayDirection: vec3<f32>,
}

struct TraceOutput {
    pixel: Pixel,
    temporalData: TemportalData,
    seed: f32,
}

struct TreePart {
    minPosition: vec3<f32>,
    padding0: f32,
    maxPosition: vec3<f32>,
    padding1: f32,

    child1: f32,
    child2: f32,
    padding2: f32,
    padding3: f32,

    triangles: array<f32, 8>,
}

struct OutputTextureData {
    staticFrames: f32,
    totalFrames: f32
}

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;

@group(1) @binding(0) var<storage, read> inputMap: InputMapData;
@group(1) @binding(1) var<storage, read> inputLightMap: InputLightData;
@group(1) @binding(2) var<storage, read> inputMaterials: array<Material>;
@group(1) @binding(3) var<storage, read> inputTreeParts: array<TreePart>;

@group(1) @binding(4) var textureAtlas: texture_2d_array<f32>;
@group(1) @binding(5) var textureAtlasSampler: sampler;

@group(1) @binding(6) var worldTexture: texture_2d<f32>;
@group(1) @binding(7) var worldTextureSampler: sampler;

@group(2) @binding(0) var image_color_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(1) var image_normal_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(2) var image_depth_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(3) var image_albedo_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(4) var image_object_texture: texture_storage_2d<r32float, write>;

@group(3) @binding(0) var<storage, read> image_history_data: OutputTextureData;

#include "functions/calculate_pixel.wgsl"

fn isNan(num: f32) -> bool {
    return (bitcast<u32>(num) & 0x7fffffffu) > 0x7f800000u;
}

@compute @workgroup_size(16, 16, 1) 
fn computeMain(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    if (f32(global_invocation_id.x) >= inputData.resolution.x || f32(global_invocation_id.y) >= inputData.resolution.y) {
        return;
    }

    //let index = global_invocation_id.x + global_invocation_id.y * u32(inputData.resolution.x);

    var avarageColor: vec4<f32>;
    var avarageAlbedo: vec3<f32>;
    var avarageNormal: vec3<f32>;
    var averageIntersection: vec3<f32>;
    var avarageDepth: f32;

    var maxRays: f32 = 1;
    var raysDone: f32 = 0;
    //var maxRays: f32 = 5;
    var seed = image_history_data.totalFrames;
    var object: f32 = 0;

    for(var rayNum = 0; rayNum < i32(maxRays); rayNum++){
        let pixelData = calculatePixelColor(vec2<f32>(global_invocation_id.xy), seed);
        seed = pixelData.seed;
        if(isNan(pixelData.pixel.noisy_color.x) || isNan(pixelData.pixel.noisy_color.y) || isNan(pixelData.pixel.noisy_color.z) || isNan(pixelData.pixel.noisy_color.w)){ continue; }

        avarageColor += pixelData.pixel.noisy_color;
        avarageAlbedo += pixelData.pixel.albedo;
        avarageNormal += pixelData.pixel.normal;
        avarageDepth += pixelData.pixel.depth;

        raysDone += 1;
        averageIntersection += pixelData.pixel.intersection;
        object = pixelData.pixel.object_id;
    }

    //imageBuffer[index] = pixelData.pixel;
    //temporalBuffer[index] = pixelData.temporalData;

    if(raysDone == 0) {return; }
    if(isNan(avarageColor.x) || isNan(avarageColor.y) || isNan(avarageColor.z) || isNan(avarageColor.w)){ return; }

    textureStore(image_color_texture, global_invocation_id.xy, avarageColor / raysDone);
    textureStore(image_albedo_texture, global_invocation_id.xy, vec4<f32>(avarageAlbedo / raysDone, 0));
    textureStore(image_normal_texture, global_invocation_id.xy, vec4<f32>(avarageNormal / raysDone, 0));
    textureStore(image_depth_texture, global_invocation_id.xy, vec4<f32>(averageIntersection / raysDone, avarageDepth / raysDone));
    textureStore(image_object_texture, global_invocation_id.xy, vec4<f32>(object, 0, 0, 0));
}