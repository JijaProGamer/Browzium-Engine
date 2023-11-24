const verticesPos = array(
    vec2f( -1.0,  -1.0),
    vec2f( 1.0,  -1.0),
    vec2f( -1.0,  1.0),
    
    vec2f( -1.0,  1.0),
    vec2f( 1.0,  -1.0),
    vec2f( 1.0,  1.0),
);

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
};

@vertex 
fn vertexMain(@builtin(vertex_index) vertexIndex : u32) -> VertexOutput {
    var out: VertexOutput;

    out.position = vec4<f32>(verticesPos[vertexIndex], 0.0, 1.0);
    
    return out;
}