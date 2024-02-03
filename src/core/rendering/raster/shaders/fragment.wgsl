/*struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,
    padding0: f32,

    CameraToWorldMatrix: mat4x4<f32>,
};

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;*/

struct Vertex {
    @builtin(position) position : vec4<f32>,
    @location(0) normal : vec4<f32>,
    @location(1) uv : vec4<f32>
};

@fragment
fn fragmentMain(fragData: Vertex) -> @location(0) vec4<f32>
{
    //let
    return vec4<f32>(fragData.normal.xyz, 1);
    //return vec4<f32>(1, 0, 1, 1);
}