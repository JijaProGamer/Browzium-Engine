[[group(0), binding(0)]] var colorMap: texture_2d<f32>;
[[group(0), binding(1)]] var normalMap: texture_2d<f32>;
[[group(0), binding(2)]] var posMap: texture_2d<f32>;

var c_phi: f32;
var n_phi: f32;
var p_phi: f32;
var stepwidth: f32;

var kernel: array<f32, 25>;
var offset: array<vec2<f32>, 25>;

[[location(0)]] fn main([[location(0)]] in fs_input : vec2<f32>) -> [[location(0)]] vec4<f32> {
    var sum: vec4<f32> = vec4<f32>(0.0);
    var step: vec2<f32> = vec2<f32>(1.0 / 512.0, 1.0 / 512.0); // resolution

    var cval: vec4<f32> = textureSample(colorMap, fs_input);
    var nval: vec4<f32> = textureSample(normalMap, fs_input);
    var pval: vec4<f32> = textureSample(posMap, fs_input);

    var cum_w: f32 = 0.0;

    for (var i: i32 = 0; i < 25; i = i + 1) {
        var uv: vec2<f32> = fs_input + offset[i] * step * stepwidth;
        var ctmp: vec4<f32> = textureSample(colorMap, uv);

        var t: vec4<f32> = cval - ctmp;
        var dist2: f32 = dot(t, t);
        var c_w: f32 = min(exp(-dist2 / c_phi), 1.0);

        var ntmp: vec4<f32> = textureSample(normalMap, uv);
        t = nval - ntmp;
        dist2 = max(dot(t, t) / (stepwidth * stepwidth), 0.0);
        var n_w: f32 = min(exp(-dist2 / n_phi), 1.0);

        var ptmp: vec4<f32> = textureSample(posMap, uv);
        t = pval - ptmp;
        dist2 = dot(t, t);
        var p_w: f32 = min(exp(-dist2 / p_phi), 1.0);

        var weight: f32 = c_w * n_w * p_w;
        sum = sum + ctmp * weight * kernel[i];
        cum_w = cum_w + weight * kernel[i];
    }

    return vec4<f32>(sum / cum_w);
}
