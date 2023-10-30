/*@vertex
fn main(@location(0) pos: vec2f) -> @builtin(position) vec4f {
  return vec4f(pos, 0, 1);
}*/

struct VertexShaderOutput {
  @builtin(position) position: vec4f,
  @location(0) texcoord: vec2f,
};

@vertex 
fn main(@builtin(vertex_index) vertexIndex : u32) -> VertexShaderOutput {
  let pos = array(
    vec2f( 0.0,  0.0),
    vec2f( 1.0,  0.0),
    vec2f( 0.0,  1.0),

    vec2f( 0.0,  1.0),
    vec2f( 1.0,  0.0),
    vec2f( 1.0,  1.0),
  );

  var vsOutput: VertexShaderOutput;
  let xy = pos[vertexIndex];
  vsOutput.position = vec4f(xy, 0.0, 1.0);
  vsOutput.texcoord = xy;
  
  return vsOutput;
}