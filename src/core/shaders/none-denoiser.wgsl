@group(0) @binding(0) var colorMap: texture_2d<f32>;
@group(0) @binding(1) var albedoMap: texture_2d<f32>;
@group(0) @binding(2) var output: texture_storage_2d<rgba16float, write>;

@compute @workgroup_size(16, 16, 1) 
fn computeMain(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    var color = textureLoad(colorMap, global_invocation_id.xy, 0);
    var albedo = textureLoad(albedoMap, global_invocation_id.xy, 0);

    textureStore(output, global_invocation_id.xy, color * albedo);

    /*var color = textureLoad(colorMap, global_invocation_id.xy, 0);

    textureStore(output, global_invocation_id.xy, color);*/
}
