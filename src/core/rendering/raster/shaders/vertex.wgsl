struct InputGlobalData {
    CameraToWorldMatrix: mat4x4<f32>,
};

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;

struct VertexOut {
    @builtin(position) position : vec4<f32>,
    @location(0) normal : vec4<f32>,
    @location(1) uv : vec4<f32>

};

@vertex
fn vertexMain(@location(0) position: vec4<f32>,
            @location(1) normal: vec4<f32>,
            @location(2) uv: vec4<f32>,
) -> VertexOut {

    var vertexPos = inputData.CameraToWorldMatrix * position;
    //vertexPos /= vertexPos.z;

    var output : VertexOut;
    output.position = vertexPos;
    output.normal = normal;
    output.uv = uv;

    return output;
}