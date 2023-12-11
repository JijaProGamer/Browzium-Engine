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
    maxStep: f32, // Is it the max step?
}

const offset = array<vec2<f32>, 25>(
    vec2<f32>(-2.0, -2.0), vec2<f32>(-1.0, -2.0), vec2<f32>(0.0, -2.0), vec2<f32>(1.0, -2.0), vec2<f32>(2.0, -2.0),
    vec2<f32>(-2.0, -1.0), vec2<f32>(-1.0, -1.0), vec2<f32>(0.0, -1.0), vec2<f32>(1.0, -1.0), vec2<f32>(2.0, -1.0),
    vec2<f32>(-2.0, 0.0), vec2<f32>(-1.0, 0.0), vec2<f32>(0.0, 0.0), vec2<f32>(1.0, 0.0), vec2<f32>(2.0, 0.0),
    vec2<f32>(-2.0, 1.0), vec2<f32>(-1.0, 1.0), vec2<f32>(0.0, 1.0), vec2<f32>(1.0, 1.0), vec2<f32>(2.0, 1.0),
    vec2<f32>(-2.0, 2.0), vec2<f32>(-1.0, 2.0), vec2<f32>(0.0, 2.0), vec2<f32>(1.0, 2.0), vec2<f32>(2.0, 2.0)
);

const kernel = array<f32, 25>(
        1.0 / 256.0, 1.0 / 64.0, 3.0 / 128.0, 1.0 / 64.0, 1.0 / 256.0,
        1.0 / 64.0, 1.0 / 16.0, 3.0 / 32.0, 1.0 / 16.0, 1.0 / 64.0,
        3.0 / 128.0, 3.0 / 32.0, 9.0 / 64.0, 3.0 / 32.0, 3.0 / 128.0,
        1.0 / 64.0, 1.0 / 16.0, 3.0 / 32.0, 1.0 / 16.0, 1.0 / 64.0,
        1.0 / 256.0, 1.0 / 64.0, 3.0 / 128.0, 1.0 / 64.0, 1.0 / 256.0
);

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;

@group(1) @binding(0) var colorMap: texture_2d<f32>;
@group(1) @binding(1) var normalMap: texture_2d<f32>;
@group(1) @binding(2) var depthMap: texture_2d<f32>;
@group(1) @binding(3) var albedoMap: texture_2d<f32>;
@group(1) @binding(4) var objectMap: texture_2d<f32>;
@group(1) @binding(5) var output: texture_storage_2d<rgba16float, write>;

@group(2) @binding(0) var<storage, read> inputFilteringData: FilteringData;

fn isNan(num: f32) -> bool {
    return (bitcast<u32>(num) & 0x7fffffffu) > 0x7f800000u;
}

@compute @workgroup_size(16, 16, 1) 
fn computeMain(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    var accumulatedColor = vec4<f32>(0.0);
    
    let cval = textureLoad(colorMap, global_invocation_id.xy, 0);
    let nval = textureLoad(normalMap, global_invocation_id.xy, 0);
    let pval = textureLoad(depthMap, global_invocation_id.xy, 0);
    let oval = textureLoad(objectMap, global_invocation_id.xy, 0).x;
    
    var cum_w = 0.0;
    for(var i: i32 = 0; i < 25; i++)
    {
        let uv = vec2<u32>(vec2<f32>(global_invocation_id.xy) + offset[i] * inputFilteringData.stepwidth);
        let neighborObject = textureLoad(objectMap, uv, 0).x;
        if(neighborObject != oval){ continue; }
        
        let ctmp = textureLoad(colorMap, uv, 0);
        if(/*ctmp.w < 1 || */isNan(ctmp.x) || isNan(ctmp.y) || isNan(ctmp.z) || isNan(ctmp.w)){ continue; }

        var t = cval - ctmp;
        var dist2 = dot(t,t);
        let c_w = min(exp(-(dist2)/inputFilteringData.c_phi), 1.0);
        
        let ntmp = textureLoad(normalMap, uv, 0);
        t = nval - ntmp;
        dist2 = max(dot(t,t), 0.0);
        let n_w = min(exp(-(dist2)/inputFilteringData.n_phi), 1.0);
        
        let ptmp = textureLoad(depthMap, uv, 0);
        t = pval - ptmp;
        t.w = 0;
        dist2 = dot(t,t);
        let p_w = min(exp(-(dist2)/inputFilteringData.p_phi), 1.0);
        
        let weight = c_w * n_w * p_w;
        accumulatedColor += ctmp * weight * kernel[i];
        cum_w += weight * kernel[i];
    }

    accumulatedColor /= cum_w;
    //accumulatedColor *= 2.56;
    accumulatedColor.a = 1;

    if (inputFilteringData.maxStep == 1) {
        let originalAlpha = accumulatedColor.a;
        //let originalAlpha = 1.0;
        accumulatedColor *= textureLoad(albedoMap, global_invocation_id.xy, 0);
        accumulatedColor.a = originalAlpha;
    }

    if(isNan(accumulatedColor.x) || isNan(accumulatedColor.y) || isNan(accumulatedColor.z) || isNan(accumulatedColor.w)){ return; }

    textureStore(output, global_invocation_id.xy, accumulatedColor);
}