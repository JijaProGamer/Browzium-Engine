/*@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
  return vec4f(0.2, 0.5, 0.5, 1);
}*/

struct VertexShaderOutput {
  @builtin(position) position: vec4f,
  @location(0) texcoord: vec2f,
};

@group(0) @binding(0) var renderSampler: sampler;
@group(0) @binding(1) var renderTexture: texture_2d<f32>;

@fragment 
fn main(fsInput: VertexShaderOutput) -> @location(0) vec4f {
  let texcoord = vec2f(fsInput.texcoord.x, 1.0 - fsInput.texcoord.y);
  return textureSample(renderTexture, renderSampler, texcoord);
}