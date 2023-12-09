struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,

    padding0: f32,
    CameraPosition: vec3<f32>,

    padding1: f32,
    CameraToWorldMatrix: mat4x4<f32>,

    tonemapmode: f32,
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

    reflectance: f32,
    emittance: f32,
};

struct InputMapData {
    triangle_count: f32,
    padding0: f32,
    padding1: f32,
    padding2: f32,
    triangles: array<Triangle>,
};

struct Pixel {
    noisy_color: vec4<f32>,
    albedo: vec3<f32>,
    normal: vec3<f32>,
    velocity: vec2<f32>,
    depth: f32,
    //depth: f32,
    //albedo: array<u32, 3>,
}

struct TemportalData {
    rayDirection: vec3<f32>,
}

struct TraceOutput {
    pixel: Pixel,
    temporalData: TemportalData,
}

struct TreePart {
    center: vec3<f32>,
    padding0: f32,

    halfSize: f32,
    children: array<f32, 8>,
    triangles: array<f32, 16>,
    padding1: f32,

    padding2: f32,
    padding3: f32
}

struct OutputTextureData {
    staticFrames: f32,
    totalFrames: f32
}

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;



@group(1) @binding(0) var<storage, read> inputMap: InputMapData;
@group(1) @binding(1) var<storage, read> inputMaterials: array<Material>;
@group(1) @binding(2) var<storage, read> inputTreeParts: array<TreePart>;



@group(2) @binding(0) var image_color_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(1) var image_color_texture_read: texture_2d<f32>;

@group(2) @binding(2) var image_normal_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(3) var image_normal_texture_read: texture_2d<f32>;

@group(2) @binding(4) var image_depth_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(5) var image_depth_texture_read: texture_2d<f32>;

@group(2) @binding(6) var image_albedo_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(7) var image_albedo_texture_read: texture_2d<f32>;

@group(2) @binding(8) var image_history: texture_storage_2d<rgba16float, write>;
@group(2) @binding(9) var image_history_read: texture_2d<f32>;

@group(2) @binding(10) var<storage, read> image_history_data: OutputTextureData;

@group(2) @binding(11) var<storage, read_write> temporalBuffer: array<TemportalData>;

//@group(2) @binding(0) var<storage, read_write> imageBuffer: array<Pixel>;
///@group(2) @binding(1) var image_color_sampler: sampler;
///@group(2) @binding(2) var<storage, read_write> temporalBuffer: array<TemportalData>;

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


struct HitResult {
    depth: f32,
    hit: bool,

    material: Material,

    normal: vec3<f32>,
    position: vec3<f32>
}

struct OctreeHitResult {
    hit: bool,
    treePart: TreePart,
}

const errorAmount = 0.000001;

fn hit_triangle(tri: Triangle, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> HitResult {
    var result: HitResult;

    if(!is_triangle_facing_camera(tri, ray_direction)){
        return result;
    }

    let edge1 = tri.b - tri.a;
    let edge2 = tri.c - tri.a;
    let h = cross(ray_direction, edge2);
    let a = dot(edge1, h);

    if (a > -errorAmount && a < errorAmount) {
        return result;
    }

    let f = 1.0 / a;
    let s = ray_origin - tri.a;
    let u = f * dot(s, h);

    if u < 0.0 || u > 1.0 {
        return result;
    }

    let q = cross(s, edge1);
    let v = f * dot(ray_direction, q);

    if v < 0.0 || u + v > 1.0 {
        return result;
    }

    let t = f * dot(edge2, q);

    if(t < errorAmount){
        return result;
    }

    result.hit = true;
    result.depth = t;
    result.normal = normalize((1.0 - u - v) * tri.na + u * tri.nb + v * tri.nc);
    result.position = ray_origin + ray_direction * t;

    return result;
}

fn hit_octree(ray_origin: vec3<f32>, ray_direction: vec3<f32>, box: TreePart) -> bool {
    var half_extent: vec3<f32> = vec3<f32>(box.halfSize, box.halfSize, box.halfSize);
    var box_min: vec3<f32> = box.center - half_extent;
    var box_max: vec3<f32> = box.center + half_extent;

    var t_min: vec3<f32> = (box_min - ray_origin) / ray_direction;
    var t_max: vec3<f32> = (box_max - ray_origin) / ray_direction;

    var t1: vec3<f32> = min(t_min, t_max);
    var t2: vec3<f32> = max(t_min, t_max);

    var t_enter: f32 = max(max(t1.x, t1.y), t1.z);
    var t_exit: f32 = min(min(t2.x, t2.y), t2.z);

    return t_enter <= t_exit;
}

fn get_ray_intersection(ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> HitResult {
    var depth: f32 = 9999999;
    var result: HitResult;

    for (var i: f32 = 0; i < inputMap.triangle_count; i = i + 1) {
        let currentTriangle = inputMap.triangles[i32(i)];
        let current_result = hit_triangle(currentTriangle, ray_origin, ray_direction);

        if (current_result.hit && current_result.depth < depth) {
            result = current_result;
            depth = result.depth;
            result.material = inputMaterials[i32(currentTriangle.material_index)];
        }
    }

    return result;
}

/*fn get_ray_intersection(ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> HitResult {
    var depth: f32 = 9999999;
    var result: HitResult;

    var stack: array<TreePart, 64>;
    var stackIndex: i32 = 0;

    stack[stackIndex] = inputTreeParts[0];
    stackIndex++;

    if (!hit_octree(ray_origin, ray_direction, stack[0])) {
        return result;
    }

    while (stackIndex > 0) {
        stackIndex--;
        let currentBox = stack[stackIndex];

        let hit = hit_octree(ray_origin, ray_direction, currentBox);

        if (hit) {
            if (currentBox.children[0] == -1.0) {
                for (var i: f32 = 0; i < 16; i = i + 1) {
                    let triIndex = i32(currentBox.triangles[i32(i)]);
                    if(triIndex == -1) { break; }

                    let currentTriangle = inputMap.triangles[triIndex];
                    let current_result = hit_triangle(currentTriangle, ray_origin, ray_direction);

                    if (current_result.hit && current_result.depth < depth) {
                        result = current_result;
                        depth = result.depth;
                        result.material = inputMaterials[i32(currentTriangle.material_index)];
                    }
                }

                continue;
            }

            for (var i: i32 = 0; i < 8; i = i + 1) {
                let childIndex = currentBox.children[i];
                let childNode = inputTreeParts[i32(childIndex)];

                if (hit_octree(ray_origin, ray_direction, childNode)) {
                    stack[stackIndex] = childNode;
                    stackIndex++;
                }
            }
        }
    }


    return result;
}*/

fn is_triangle_facing_camera(tri: Triangle, ray_direction: vec3<f32>) -> bool {
    let dotProductA = dot(tri.na, ray_direction);
    let dotProductB = dot(tri.nb, ray_direction);
    let dotProductC = dot(tri.nc, ray_direction);
    
    return dotProductA < 0.0 && dotProductB < 0.0 && dotProductC < 0.0;
}
fn hash(x: u32) -> u32 {
    var output: u32 = x;

    output = output + (output << 10u);
    output = output ^ (output >> 6u);
    output = output + (output << 3u);
    output = output ^ (output >> 11u);
    output = output + (output << 15u);
    
    return output;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    let f: f32 = bitcast<f32>(mBits);
    return f - 1.0;
}

struct Random3Vec3Output {
    output: vec3<f32>,
    seed: f32
};

struct Random3Vec2Output {
    output: vec2<f32>,
    seed: f32
};

fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    var vector = vec3<f32>(seed, vec);

    vector = fract(vector * 0.75318531);
    vector += dot(vector, vector.zyx + .4143);

    return fract((vector.x * .2144 + vector.y / .19153) * vector.z / (vector.x*vector.x));
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> Random3Vec2Output {
    var vector = vec3<f32>(seed, vec);
    var output: Random3Vec2Output;

    vector = fract(vector * vec3<f32>(0.1031, 0.1030, 0.0973));
    vector += dot(vector, vector.yzx + 33.33);
    var outputVector = fract((vector.xx + vector.yz) * vector.zy) - vec2<f32>(0.5);

    output.seed = outputVector.y + outputVector.x / .43145 + seed * 2.634145;
    output.output = outputVector;

    return output;
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> Random3Vec3Output {
    var vector = vec4<f32>(seed, vec);
    var output: Random3Vec3Output;

    vector = fract(vector * vec4<f32>(.9898, 78.233, 43.094, 94.457));
    vector += dot(vector, vector.wzxy + 33.33);
    vector = fract((vector.xxyz + vector.yzzw) * vector.zywx) - vec4<f32>(0.5);

    output.seed = vector.y * seed * .65376464 + vector.x - vector.z * vector.w;
    output.output = vector.wxz;

    return output;
}

fn randomPoint(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var output = random3Vec3(seed, position);
    output.output = normalize(output.output);
    return output;
}

fn randomPoint2(seed: f32, position: vec2<f32>) -> Random3Vec2Output {
    var output = random2Vec2(seed, position);
    output.output = normalize(output.output);
    return output;
}

fn randomPointInHemisphere(seed: f32, normal: vec3<f32>, position: vec3<f32>) -> Random3Vec3Output {
    var randomVec: Random3Vec3Output;
    var randomiser: f32 = seed;
    var tries: i32 = 0;

    while (true) {
        randomVec = randomPoint(randomiser, position);
        randomiser = randomVec.seed;
        tries += 1;

        if (length(randomVec.output) <= 1.0 || tries > 10) {
            randomVec.output = normalize(randomVec.output);
            randomVec.seed = randomiser;
            break;
        }
    }

    if (dot(randomVec.output, normal) < 0.0) {
        randomVec.output = -randomVec.output;
    }

    return randomVec;
}


fn NoHit(
    direction: vec3<f32>, 
    start: vec3<f32>
) -> vec3<f32> {
    let a = 0.5 * (direction.y + 1.0);

    let White = vec3<f32>(0.8, 0.8, 0.8);
    let Blue = vec3<f32>(0.15, 0.3, 0.9);

    return (0.7-a) * White + (a + 0.3) * Blue;
}


const maxDepth: i32 = 5;

fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    var realDirection = direction;
    var realStart = start;
    var accumulatedColor = vec3<f32>(1);
    var pixelHash = rawPixelHash;
    var hit_light = false;
    var depth: i32 = 0;

    for (; depth <= maxDepth; depth = depth + 1) {
        if (depth >= maxDepth) {
            break;
        }

        var intersection = get_ray_intersection(realStart, realDirection);
        var material = intersection.material;
        var emittance = material.color * material.emittance;

        if(depth == 0){
            if (!intersection.hit) { 
                intersection.depth = 999999; 
                intersection.normal = -realDirection; 
                material.color = NoHit(realDirection, realStart);
            }

            output.normal = intersection.normal;
            output.depth = intersection.depth;
            output.albedo = material.color;
        }

        if (!intersection.hit) {
            hit_light = true;
            accumulatedColor *= NoHit(realDirection, realStart);
            break;
        }

        let newDirectionValue = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
        let reflected = (realDirection - 2.0 * dot(realDirection, intersection.normal) * intersection.normal);
        let newDirection = normalize((1 - material.reflectance) *  newDirectionValue.output + material.reflectance * reflected);

        pixelHash = newDirectionValue.seed;

        let p = 1.0 / (2.0 * 3.141592653589);
        let cos_theta = dot(newDirection, intersection.normal);
        
        var BRDF = (max(1 - material.emittance, 0) * material.color) / 3.141592653589;
        BRDF *= 1.0 - step(0.5, f32(depth)); // remove albedo from first bounce, we only want the noisy data
        //emittance *= max(f32(depth), 1);

        accumulatedColor *= emittance + (BRDF * cos_theta / p);

        if(material.emittance > 0){
            hit_light = true;
            break;
        }

        realStart = intersection.position;
        realDirection = newDirection;
    }

    //if(true){
    if(hit_light){
        output.noisy_color = vec4<f32>(accumulatedColor, 1);
    }

    return output;
}

fn getTemporalData(
    pixel: vec2<f32>
) -> TemportalData {
    return temporalBuffer[u32(pixel.x + pixel.y * inputData.resolution.x)];
}

fn calculatePixelDirection(
    pixel: vec2<f32>
) -> vec3<f32> {
    let depth = tan(inputData.fov * (3.14159265358979323846 / 180.0) / 2.0);
    let aspectRatio = inputData.resolution.x / inputData.resolution.y;

    let ndcX = (f32(pixel.x) + 0.5) / inputData.resolution.x;
    let ndcY = (f32(pixel.y) + 0.5) / inputData.resolution.y;

    let screenX = 2 * ndcX - 1;
    let screenY = 1 - 2 * ndcY;

    let cameraX = screenX * aspectRatio * depth;
    let cameraY = screenY * depth;

    return (inputData.CameraToWorldMatrix * vec4<f32>(cameraX, cameraY, -1, 1)).xyz;
}

fn calculateTemporalData(
    pixel: vec2<f32>,
    traceOutput: Pixel,
    start: vec3<f32>,
    direction: vec3<f32>,
) -> TemportalData {
    var output: TemportalData;

    output.rayDirection = direction;

    return output;
}

fn calculatePixelColor(
    pixel: vec2<f32>
) -> TraceOutput {
    var pixelHash = randomVec2(image_history_data.totalFrames, pixel);

    var pixelModifier = randomPoint2(pixelHash, pixel);
    pixelHash = pixelModifier.seed;

    var realPixel = pixel + (pixelModifier.output + vec2<f32>(1, 1)) / 2;

    let direction = calculatePixelDirection(realPixel);
    let start = inputData.CameraPosition;

    var output: TraceOutput;

    //let temporalData = getTemporalData(realPixel);
    var traceOutput = RunTracer(direction, start, pixel, pixelHash);

    //traceOutput.velocity = (temporalData.rayDirection - direction).xy;

    output.pixel = traceOutput;
    //output.temporalData = calculateTemporalData(realPixel, traceOutput, start, direction);

    return output;
}
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
const ACES_a = 2.51;
const ACES_b = 0.03;
const ACES_c = 2.43;
const ACES_d = 0.59;
const ACES_e = 0.14;

fn applyACES(x: vec3<f32>) -> vec3<f32> {
    return clamp((x * (ACES_a * x + ACES_b)) / (x * (ACES_c * x + ACES_d) + ACES_e), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn isNan(num: f32) -> bool {
    return num != num || (bitcast<u32>(num) & 0x7fffffffu) > 0x7f800000u;
}

@fragment 
fn fragmentMain(fsInput: VertexOutput) -> @location(0) vec4f {
    var pixelPosition = vec2<i32>(fsInput.position.xy);

    var pixel = textureLoad(image_color_texture_read, pixelPosition, 0);
    //var pixel = textureLoad(image_albedo_texture_read, pixelPosition, 0);

    //var pixel = imageBuffer[index].noisy_color;
    //var temporalData = temporalBuffer[index];

    if(image_history_data.staticFrames == 0){
        textureStore(image_history, pixelPosition, vec4<f32>(0, 0, 0, 0));
    } else {
        let w = pixel.w;

        let historyPixel = textureLoad(image_history_read, pixelPosition, 0);
        pixel = mix(historyPixel, pixel, clamp(1 / image_history_data.staticFrames, 0.002, 1));

        if(w > 0 && !(isNan(pixel.x) || isNan(pixel.y) || isNan(pixel.z) || isNan(pixel.w))){
            textureStore(image_history, pixelPosition, pixel);
        }

        pixel.w = 1;
    }

    if(inputData.tonemapmode == 1){
        pixel = vec4<f32>(applyACES(pixel.xyz), pixel.w);
    }

    if(inputData.gammacorrect == 1){
        let oldTransparency = pixel.w;
        pixel = pow(pixel, vec4<f32>(1.0 / 2.2));
        pixel.w = oldTransparency;
    }

    // Displaying

    //return vec4<f32>(position.xy / inputData.resolution, 0, 1);
    return pixel;
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
    let pixelData = calculatePixelColor(vec2<f32>(global_invocation_id.xy));

    //imageBuffer[index] = pixelData.pixel;
    //temporalBuffer[index] = pixelData.temporalData;

    textureStore(image_color_texture, global_invocation_id.xy, pixelData.pixel.noisy_color);
    textureStore(image_albedo_texture, global_invocation_id.xy, vec4<f32>(pixelData.pixel.albedo, 0));
    textureStore(image_normal_texture, global_invocation_id.xy, vec4<f32>(pixelData.pixel.normal, 0));
    textureStore(image_depth_texture, global_invocation_id.xy, vec4<f32>(pixelData.pixel.depth, 0, 0, 0));
}