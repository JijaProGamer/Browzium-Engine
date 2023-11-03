/*@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
  return vec4f(0.2, 0.5, 0.5, 1);
}*/

struct VertexShaderOutput {
  @builtin(position) position: vec4f,
  @location(0) texcoord: vec2f,
};

struct InputGlobalData {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<storage, read> storageBuffer: array<f32>;
@group(0) @binding(1) var<storage, read> inputData: InputGlobalData;

@fragment 
fn main(
  @builtin(position) position: vec4<f32>,
) -> @location(0) vec4f {
  /*let texcoord = vec2f(fsInput.texcoord.x, 1.0 - fsInput.texcoord.y);
  return textureSample(renderTexture, renderSampler, texcoord);*/
  //return textureSample(renderTexture, renderSampler, fsInput.texcoord);
  //return vec4f(0.5, 0.2 ,0, 1);

  //return vec4f(fsInput.texcoord.x, fsInput.texcoord.y, 0.5, 1);

  let index = u32(position.x + position.y * inputData.resolution.x) * 3;
  return vec4f(storageBuffer[index], storageBuffer[index + 1], storageBuffer[index + 2], 1);
}