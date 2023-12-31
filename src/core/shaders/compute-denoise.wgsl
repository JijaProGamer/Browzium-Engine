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

struct FilteringData {
    c_phi: f32, // Filtering strenght parameter for color
    n_phi: f32, // Filtering strenght parameter for normal
    p_phi: f32, // Filtering strenght parameter for depth
    stepwidth: f32, // Step width for sampling
    maxStep: f32,

    padding0: f32,
    padding1: f32,
    padding2: f32,

    kernel: array<f32, 25>, // Filter kernel coefficients
}

const offset = array<vec2<f32>, 25>(
    vec2<f32>(-2.0, -2.0), vec2<f32>(-1.0, -2.0), vec2<f32>(0.0, -2.0), vec2<f32>(1.0, -2.0), vec2<f32>(2.0, -2.0),
    vec2<f32>(-2.0, -1.0), vec2<f32>(-1.0, -1.0), vec2<f32>(0.0, -1.0), vec2<f32>(1.0, -1.0), vec2<f32>(2.0, -1.0),
    vec2<f32>(-2.0, 0.0), vec2<f32>(-1.0, 0.0), vec2<f32>(0.0, 0.0), vec2<f32>(1.0, 0.0), vec2<f32>(2.0, 0.0),
    vec2<f32>(-2.0, 1.0), vec2<f32>(-1.0, 1.0), vec2<f32>(0.0, 1.0), vec2<f32>(1.0, 1.0), vec2<f32>(2.0, 1.0),
    vec2<f32>(-2.0, 2.0), vec2<f32>(-1.0, 2.0), vec2<f32>(0.0, 2.0), vec2<f32>(1.0, 2.0), vec2<f32>(2.0, 2.0)
);

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;

@group(1) @binding(0) var colorMap: texture_2d<f32>;
@group(1) @binding(1) var normalMap: texture_2d<f32>;
@group(1) @binding(2) var depthMap: texture_2d<f32>;
@group(1) @binding(3) var albedoMap: texture_2d<f32>;
@group(1) @binding(4) var output: texture_storage_2d<rgba16float, write>;

@group(2) @binding(0) var<storage, read> inputFilteringData: FilteringData;

@compute @workgroup_size(16, 16, 1) 
fn computeMain(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    //var pixel = textureLoad(normalMap, global_invocation_id.xy, 0);
    //var pixel = textureLoad(depthMap, global_invocation_id.xy, 0) / 10;
    //pixel.g = inputFilteringData.c_phi;

    //textureStore(output, global_invocation_id.xy, pixel);
    
    var accumulatedColor: vec4<f32> = vec4<f32>(0.0);
    
    var currentPixelColor: vec4<f32> = textureLoad(colorMap, global_invocation_id.xy, 0);
    var currentPixelNormal: vec4<f32> = textureLoad(normalMap, global_invocation_id.xy, 0);
    var currentPixelDepth: vec4<f32> = textureLoad(depthMap, global_invocation_id.xy, 0);

    var totalWeight: f32 = 0.0;

    for (var i: i32 = 0; i < 25; i = i + 1) {
        let neighborUV = global_invocation_id.xy + vec2<u32>(offset[i] * inputFilteringData.stepwidth);
        var neighborColor: vec4<f32> = textureLoad(colorMap, neighborUV, 0);

        var colorDifference: vec4<f32> = currentPixelColor - neighborColor;
        var colorDistanceSquared: f32 = dot(colorDifference, colorDifference);
        var colorWeight: f32 = min(exp(-colorDistanceSquared / inputFilteringData.c_phi), 1.0);

        var normalDifference: vec4<f32> = currentPixelNormal - textureLoad(normalMap, neighborUV, 0);
        var normalDistanceSquared: f32 = max(dot(normalDifference, normalDifference) / (inputFilteringData.stepwidth * inputFilteringData.stepwidth), 0.0);
        var normalWeight: f32 = min(exp(-normalDistanceSquared / inputFilteringData.n_phi), 1.0);

        // Only consider the x component of the depth
        var depthDifference: f32 = currentPixelDepth.x - textureLoad(depthMap, neighborUV, 0).x;
        var depthDistanceSquared: f32 = depthDifference * depthDifference;
        var depthWeight: f32 = min(exp(-depthDistanceSquared / inputFilteringData.p_phi), 1.0);

        var weight: f32 = colorWeight * normalWeight * depthWeight;
        accumulatedColor = accumulatedColor + neighborColor * weight * inputFilteringData.kernel[i];
        totalWeight = totalWeight + weight * inputFilteringData.kernel[i];
    }

    accumulatedColor = accumulatedColor / totalWeight;

    if (inputFilteringData.maxStep == 1) {
        let originalAlpha = accumulatedColor.a;
        accumulatedColor *= textureLoad(albedoMap, global_invocation_id.xy, 0);
        accumulatedColor.a = originalAlpha;
    }

    textureStore(output, global_invocation_id.xy, accumulatedColor);
}
