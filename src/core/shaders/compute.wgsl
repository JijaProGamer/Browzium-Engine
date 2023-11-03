struct InputGlobalData {
    resolution: vec2<f32>,
};

struct InputMapData {
    triangle_count: u32,
    triangles: array<u32>,
};

@group(0) @binding(0) var<storage, read_write> storageBuffer: array<f32>;
@group(0) @binding(1) var<storage, read> inputData: InputGlobalData;
@group(0) @binding(2) var<storage, read> inputMap: InputMapData;

fn run(
    pixel: vec3<u32>,
    index: u32
){
    let imageSize = u32(inputData.resolution.x * inputData.resolution.y);

    let albedoIndex = index * 3;
    let normalIndex = (index + imageSize) * 3;
    let firstBounceNormalIndex = (index + imageSize * 2) * 3;

    storageBuffer[albedoIndex + 0] = inputData.resolution.x;
    storageBuffer[albedoIndex + 1] = inputData.resolution.y;
    storageBuffer[albedoIndex + 2] = f32(index);

    /*storageBuffer[albedoIndex + 0] = f32(pixel.x) / inputData.resolution.x;
    storageBuffer[albedoIndex + 1] = f32(pixel.y) / inputData.resolution.y;
    storageBuffer[albedoIndex + 2] = 0;*/
}

@compute @workgroup_size(8, 8, 1) 
fn main(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    if(f32(global_invocation_id.x) > inputData.resolution.x || f32(global_invocation_id.y) > inputData.resolution.y){
        return;
    }

    let index = global_invocation_id.x + global_invocation_id.y * (num_workgroups.x * 8);
    run(global_invocation_id, index);
}