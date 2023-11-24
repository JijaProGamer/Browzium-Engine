struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,

    padding0: f32,
    CameraPosition: vec3<f32>,

    padding1: f32,
    CameraToWorldMatrix: mat4x4<f32>,

    antialias: f32,
    gammacorrect: f32,
};

struct Triangle {
    a: vec3<f32>,
    padding0: f32,
    b: vec3<f32>,
    padding1: f32,
    c: vec3<f32>,
    padding2: f32,

    na: vec3<f32>,
    padding3: f32,
    nb: vec3<f32>,
    padding4: f32,
    nc: vec3<f32>,
    padding5: f32,

    material_index: f32,
    padding6: f32,
    padding7: f32,
    padding8: f32,
};

struct Material {
    color: vec3<f32>,
    padding0: f32,

    transparency: f32,
    index_of_refraction: f32,

    padding1: f32,
    padding2: f32,
};

struct InputMapData {
    triangle_count: f32,
    padding0: f32,
    padding1: f32,
    padding2: f32,
    triangles: array<Triangle>,
};

struct InputMaterialData {
    materials: array<Material>,
};

struct Pixel {
    noisy_color: vec3<f32>
    //albedo: array<u32, 3>,
}

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;
@group(1) @binding(0) var<storage, read> inputMap: InputMapData;
@group(2) @binding(0) var<storage, read> inputMaterials: InputMaterialData;
@group(3) @binding(0) var<storage, read_write> imageBuffer: array<Pixel>;

struct Vector3 {
  x: f32,
  y: f32,
  z: f32,
};

fn vector_neg(v: Vector3) -> Vector3 {
  return Vector3(-v.x, -v.y, -v.z);
}

fn vector_add(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z);
}

fn vector_mul(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x * v2.x, v1.y * v2.y, v1.z * v2.z);
}

fn vector_length(v: Vector3) -> f32 {
  return sqrt(vector_length_squared(v));
}

fn vector_length_squared(v: Vector3) -> f32 {
  return vector_dot(v, v);
}

fn vector_sub(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z);
}

fn vector_mul_scalar(t: f32, v: Vector3) -> Vector3 {
   return Vector3(v.x * t, v.y * t, v.z * t);
}

fn vector_div(v1: Vector3, v2: Vector3) -> Vector3 {
  return Vector3(v1.x / v2.x, v1.y / v2.y, v1.z / v2.z);
}

fn vector_div_scalar(v: Vector3, t: f32) -> Vector3 {
  return vector_mul_scalar(1.0 / t, v);
}

fn vector_dot(v1: Vector3, v2: Vector3) -> f32 {
  return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

fn vector_cross(v1: Vector3, v2: Vector3) -> Vector3 {
    return Vector3(
        v1.y * v2.z - v1.z * v2.y,
        v1.z * v2.x - v1.x * v2.z,
        v1.x * v2.y - v1.y * v2.x
    );}

fn unit_vector(v: Vector3) -> Vector3 {
  return vector_div_scalar(v, vector_length(v));
}
struct Color {
  r: f32,
  g: f32,
  b: f32,
};

fn color_neg(v: Color) -> Color {
  return Color(-v.r, -v.g, -v.b);
}

fn color_add(v1: Color, v2: Color) -> Color {
  return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b);
}

fn color_mul(v1: Color, v2: Color) -> Color {
  return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
}

fn color_length(v: Color) -> f32 {
  return sqrt(color_length_squared(v));
}

fn color_length_squared(v: Color) -> f32 {
  return color_dot(v, v);
}

fn color_sub(v1: Color, v2: Color) -> Color {
  return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b);
}

fn color_mul_scalar(t: f32, v: Color) -> Color {
   return Color(v.r * t, v.g * t, v.b * t);
}

fn color_div(v1: Color, v2: Color) -> Color {
  return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
}

fn color_div_scalar(v: Color, t: f32) -> Color {
  return color_mul_scalar(1.0 / t, v);
}

fn color_dot(v1: Color, v2: Color) -> f32 {
  return v1.r * v2.r + v1.g * v2.g + v1.b * v2.b;
}

fn color_cross(v1: Color, v2: Color) -> Color {
  return Color(v1.g * v2.b - v1.b * v2.g, v1.b * v2.b - v1.r * v2.b, v1.r * v2.g - v1.g * v2.b);
}

fn unit_color(v: Color) -> Color {
  return color_div_scalar(v, color_length(v));
}
struct ray {
  origin: vec3<f32>,
  direction: vec3<f32>
};

fn rayAt(r: ray, t: f32) -> vec3<f32> {
  return r.origin + t * r.direction;
}


fn hit_triangle(tri: Triangle, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> f32 {
    /*if(!is_triangle_facing_camera(tri, ray_direction)){
        return -1;
    }*/

    let edge1 = tri.b - tri.a;
    let edge2 = tri.c - tri.a;
    let h = cross(ray_direction, edge2);
    let a = dot(edge1, h);

    if a > -0.00001 && a < 0.00001 {
        return -1;
    }

    let f = 1.0 / a;
    let s = ray_origin - tri.a;
    let u = f * dot(s, h);

    if u < 0.0 || u > 1.0 {
        return -1;
    }

    let q = cross(s, edge1);
    let v = f * dot(ray_direction, q);

    if v < 0.0 || u + v > 1.0 {
        return -1;
    }

    let t = f * dot(edge2, q);

    if(t < 1e-6){
        return -1;
    }

    return t;
}

fn is_triangle_facing_camera(tri: Triangle, ray_direction: vec3<f32>) -> bool {
    let dotProductA = dot(tri.na, ray_direction);
    let dotProductB = dot(tri.nb, ray_direction);
    let dotProductC = dot(tri.nc, ray_direction);
    
    return dotProductA < 0.0 && dotProductB < 0.0 && dotProductC < 0.0;
}

fn RunTracer(direction: vec3<f32>, start: vec3<f32>) -> Pixel {
    var output: Pixel;

    /*output.noisy_color.r = direction.x;
    output.noisy_color.g = direction.y;
    output.noisy_color.b = direction.z;
        
    return output;*/

    var hit: bool = false;
    var depth: f32 = 999999;
    var material: Material;

    for (var i: f32 = 0; i < inputMap.triangle_count; i = i + 1) {
        let currentTriangle = inputMap.triangles[u32(i)];
        let hit_depth = hit_triangle(currentTriangle, start, direction);

        if (hit_depth > 0 && hit_depth < depth) {
            material = inputMaterials.materials[u32(currentTriangle.material_index)];
            depth = hit_depth;
            hit = true;
        }
    }

    if(hit){
        let distance = min(0.35, depth / 25);
        //var distance: f32 = 0;

        output.noisy_color.r = material.color.x - distance;
        output.noisy_color.g = material.color.y - distance;
        output.noisy_color.b = material.color.z - distance;

        /*output.noisy_color.r = 1 - (depth / 5);
        output.noisy_color.g = 1 - (depth / 10);
        output.noisy_color.b = 0;*/
    }

    return output;
}

fn calculatePixelDirection(
    pixel: vec2<u32>
) -> vec3<f32> {
    let depth = tan(inputData.fov * (3.14159265358979323846 / 180.0) / 2.0);
    let aspectRatio = inputData.resolution.x / inputData.resolution.y;

    let ndcX = (f32(pixel.x) + 0.5) / inputData.resolution.x;
    let ndcY = (f32(pixel.y) + 0.5) / inputData.resolution.y;

    let screenX = 2 * ndcX - 1;
    let screenY = 1 - 2 * ndcY;

    let cameraX = screenX * aspectRatio * depth;
    let cameraY = screenY * depth;

    return (inputData.CameraToWorldMatrix * vec4<f32>(cameraX, cameraY, -1, 0)).xyz;
}

fn calculatePixelColor(
    pixel: vec2<u32>
) -> Pixel {
    let direction = calculatePixelDirection(pixel);
    let start = inputData.CameraPosition;

    /*let a = 0.5 * (NDC.y + 1.0);
    let White = Color(0.8, 0.8, 0.8);
    let Blue = Color(0.3, 0.5, 0.8);
    let color = color_add(color_mul_scalar((1.0-a), White), color_mul_scalar(a, Blue));

    output.noisy_color.r = color.r;
    output.noisy_color.g = color.g;
    output.noisy_color.b = color.b;*/

    /*output.noisy_color.r = (NDC.x + 1) / 2;
    output.noisy_color.g = (NDC.y + 1) / 2;
    output.noisy_color.b = (NDC.z + 1) / 2;*/

    /*output.noisy_color.r = pow(NDC.x, 1.0 / 2.2);
    output.noisy_color.g = pow(NDC.y, 1.0 / 2.2);
    output.noisy_color.b = pow(NDC.z, 1.0 / 2.2);*/

    let output = RunTracer(direction, start);

    /*output.noisy_color.r = NDC.x;
    output.noisy_color.g = NDC.y;
    output.noisy_color.b = NDC.z;*/

    //output.noisy_color.r = inputData.resolution.x;
    //output.noisy_color.g = inputData.resolution.y;
    //output.noisy_color.b = inputData.fov;

    return output;
}
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
fn pixelToIndex(position: vec2<f32>) -> u32 {
    return u32(position.x + position.y * inputData.resolution.x);
}

const FXAA_SPAN_MAX = 8.0;
const FXAA_REDUCE_MUL = 1.0 / 8.0;
const FXAA_REDUCE_MIN = 1.0 / 128.0;
const luma = vec3<f32>(0.299, 0.587, 0.114);

fn shouldApplyFXAA(color1: vec3<f32>, color2: vec3<f32>) -> bool {
    let luma = vec3<f32>(0.299, 0.587, 0.114);
    let luma1 = dot(color1, luma);
    let luma2 = dot(color2, luma);
    let lumaMin = min(luma1, luma2);
    let lumaMax = max(luma1, luma2);
    
    let lumaRange = lumaMax - lumaMin;

    return (lumaRange > 0.0) && (lumaRange > FXAA_REDUCE_MIN);
}

fn applyFXAA(centerColor: vec3<f32>, fragCoord: vec2<f32>) -> vec3<f32> {
    let lumaCenter = dot(centerColor, luma);

    let lumaTop = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, -1.0))].noisy_color, luma);
    let lumaBottom = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, 1.0))].noisy_color, luma);
    let lumaLeft = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 0.0))].noisy_color, luma);
    let lumaRight = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 0.0))].noisy_color, luma);

    let lumaMax = max(max(max(abs(lumaCenter - lumaTop), abs(lumaCenter - lumaBottom)),
                         abs(lumaCenter - lumaLeft)),
                     abs(lumaCenter - lumaRight));

    let blendFactor = clamp(1.0 / ((lumaMax * lumaMax) + 0.0001), 0.0, 1.0);

    return mix(centerColor, (
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, 1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 0.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 0.0))].noisy_color
    ) * 0.25, blendFactor);
}

/*
fn applyFXAA(centerColor: vec3<f32>, fragCoord: vec2<f32>) -> vec3<f32> {
    let lumaCenter = dot(centerColor, luma);
    var lumaMax = 0.0;

    for (var x: f32 = -1.0; x <= 1.0; x += 1.0) {
        for (var y: f32 = -1.0; y <= 1.0; y += 1.0) {
            if (x == 0.0 && y == 0.0) {
                continue;
            }

            let lumaNeighbor = dot(imageBuffer[pixelToIndex(fragCoord + vec2<f32>(x, y))].noisy_color, luma);
            lumaMax = max(lumaMax, abs(lumaCenter - lumaNeighbor));
        }
    }

    let blendFactor = clamp(1.0 / ((lumaMax * lumaMax) + 0.0001), 0.0, 1.0);

    return mix(centerColor, (
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(0.0, 1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 0.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 0.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, -1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(-1.0, 1.0))].noisy_color +
        imageBuffer[pixelToIndex(fragCoord + vec2<f32>(1.0, 1.0))].noisy_color
    ) * 0.125, blendFactor);
}
*/

@fragment 
fn fragmentMain(@builtin(position) position: vec4<f32>) -> @location(0) vec4f {
    // Indexing

    var pixelPosition = position.xy;

    if(pixelPosition.x < inputData.resolution.x / 2){
        pixelPosition.x += inputData.resolution.x / 2;
    } else {
        pixelPosition.x -= inputData.resolution.x / 2;
    }

    let index = pixelToIndex(pixelPosition);
    var pixel = imageBuffer[index].noisy_color;

    if(inputData.antialias == 1){
        pixel = applyFXAA(pixel, pixelPosition);
    }

    if(inputData.gammacorrect == 1){
        pixel = pow(pixel, vec3<f32>(1.0 / 2.2));
    }

    // Displaying

    return vec4<f32>(pixel.r, pixel.g, pixel.b, 1);
}

@compute @workgroup_size(16, 16, 1) 
fn computeMain(
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
    @builtin(workgroup_id) workgroup_id: vec3<u32>
) {
    if (f32(global_invocation_id.x) >= inputData.resolution.x || f32(global_invocation_id.y) >= inputData.resolution.y) {
        return;
    }

    let index = global_invocation_id.x + global_invocation_id.y * u32(inputData.resolution.x);
    imageBuffer[index] = calculatePixelColor(global_invocation_id.xy);
}