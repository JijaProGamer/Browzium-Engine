const verticesPos = array(
    vec2f( -1.0,  1.0),
    vec2f( 1.0,  -1.0),
    vec2f( 1.0,  1.0),

    vec2f( -1.0,  -1.0),
    vec2f( 1.0,  -1.0),
    vec2f( -1.0,  1.0),
);

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texcoord: vec2f,
};

@vertex 
fn vertexMain(@builtin(vertex_index) vertexIndex : u32) -> VertexOutput {
    var out: VertexOutput;
    let vertice = verticesPos[vertexIndex];

    out.position = vec4<f32>(vertice, 0.0, 1.0);
    out.texcoord = (vertice + vec2f(1, 1)) / 2;
    
    return out;
}