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
    object_id: f32,
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
    object_id: f32,
    intersection: vec3<f32>,
}

struct TemportalData {
    rayDirection: vec3<f32>,
}

struct TraceOutput {
    pixel: Pixel,
    temporalData: TemportalData,
    seed: f32,
}

struct TreePart {
    minPosition: vec3<f32>,
    padding0: f32,
    maxPosition: vec3<f32>,
    padding1: f32,

    child1: f32,
    child2: f32,
    padding2: f32,
    padding3: f32,

    triangles: array<f32, 8>,
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
@group(2) @binding(1) var image_normal_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(2) var image_depth_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(3) var image_albedo_texture: texture_storage_2d<rgba16float, write>;
@group(2) @binding(4) var image_object_texture: texture_storage_2d<r32float, write>;

@group(3) @binding(0) var<storage, read> image_history_data: OutputTextureData;

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
    object_id: f32,

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
    let invD = 1 / ray_direction;
	let t0s = (box.minPosition - ray_origin) * invD;
  	let t1s = (box.maxPosition - ray_origin) * invD;
    
  	let tsmaller = min(t0s, t1s);
    let tbigger  = max(t0s, t1s);
    
    let tmin = max(tsmaller[0], max(tsmaller[1], tsmaller[2]));
    let tmax = min(tbigger[0], min(tbigger[1], tbigger[2]));

	return tmin < tmax && tmax > 0;
}

/*
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
}*/



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
            result.object_id = currentTriangle.object_id;
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
            if (currentBox.child1 == -1.0) {
                for (var i: f32 = 0; i < 8; i = i + 1) {
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

            let childIndex1 = currentBox.child1;
            let childNode1 = inputTreeParts[i32(childIndex1)];

            if (hit_octree(ray_origin, ray_direction, childNode1)) {
                stack[stackIndex] = childNode1;
                stackIndex++;
            }

            let childIndex2 = currentBox.child2;
            let childNode2 = inputTreeParts[i32(childIndex2)];

            if (hit_octree(ray_origin, ray_direction, childNode2)) {
                stack[stackIndex] = childNode2;
                stackIndex++;
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
fn hash(input: u32) -> u32 {
    var x = input;

    x ^= x >> 17;
    x *= 0xed5ad4bb;
    x ^= x >> 11;
    x *= 0xac4c1b51;
    x ^= x >> 15;
    x *= 0x31848bab;
    x ^= x >> 14;
    
    return x;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    let f: f32 = bitcast<f32>(mBits);
    return f - 1.0;
}

fn inverseFloatConstruct(f: f32) -> u32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u;

    let fBits: u32 = bitcast<u32>(f);
    let mBits: u32 = fBits & ieeeMantissa;

    let mantissaWithImplicitBit: u32 = mBits | ieeeOne;
    return mantissaWithImplicitBit;
}

struct Random3Vec3Output {
    output: vec3<f32>,
    seed: f32
};

struct Random3Vec2Output {
    output: vec2<f32>,
    seed: f32
};

fn random(seed: f32) -> f32 {
    return floatConstruct(hash(inverseFloatConstruct(seed)));
}

fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    var vector = vec3<f32>(seed, vec);

    vector = fract(vector * 0.75318531);
    vector += dot(vector, vector.zyx + .4143);

    return random(vector.x + vector.y + vector.z);
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> Random3Vec2Output {
    var vector = vec3<f32>(seed, vec);
    var output: Random3Vec2Output;

    vector = fract(vector * vec3<f32>(0.1031, 0.1030, 0.0973));
    vector += dot(vector, vector.yzx + 33.33);

    var outputVector = fract((vector.xx + vector.yz) * vector.zy) - vec2<f32>(0.5);

    outputVector = vec2<f32>(random(outputVector.x), random(outputVector.y)); // tap tap ingerasi

    output.seed = outputVector.y + outputVector.x / .43145 + seed * 2.634145;
    output.output = outputVector;
    
    return output;
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> Random3Vec3Output {
    var vector = vec4<f32>(seed, vec);
    var output: Random3Vec3Output;

    vector = fract(vector * vec4<f32>(.9898, 78.233, 43.094, 94.457));
    vector += dot(vector, vector.wzxy + 33.33);

    vector = vec4<f32>(random(vector.x), random(vector.y), random(vector.z), random(vector.w)); // tap tap ingerasi
    vector = fract((vector.xxyz + vector.yzzw) * vector.zywx);

    vector -= vec4<f32>(0.5);

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
    randomVec.seed = seed;

    var r1: f32 = random(seed);
    var r2: f32 = random(r1 * seed * random(position.x / position.y + position.z * 33.33));

    var phi: f32 = 2.0 * 3.141592653589793 * r1;
    var cosTheta: f32 = sqrt(1.0 - r2);
    var sinTheta: f32 = sqrt(r2);

    var x: f32 = cos(phi) * sinTheta;
    var y: f32 = cosTheta;
    var z: f32 = sin(phi) * sinTheta;

    //var hemisphereSample: vec3<f32> = normalize(vec3<f32>(x - 0.5, y - 0.5, z - 0.5));
    var hemisphereSample: vec3<f32> = normalize(vec3<f32>(x, y, z));

    if (dot(hemisphereSample, normal) >= 0.0) {
        randomVec.output = hemisphereSample;
    } else {
        randomVec.output = -hemisphereSample;
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
const russianRuleteProbability = 1.0 / 5.0;

fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    var realDirection = direction;
    var realStart = start;
    var accumulatedColor = vec3<f32>(1);
    var pixelHash = rawPixelHash;
    var hit_light = false;
    var depth: i32 = 0;

    var applyRotation = false;
    var fistColor = vec3<f32>(1);

    for (; depth <= maxDepth; depth = depth + 1) {
        if (depth >= maxDepth) {
            break;
        }

        var intersection = get_ray_intersection(realStart, realDirection);
        var material = intersection.material;
        var emittance = material.color * material.emittance;

        let isSpecular = random(pixelHash);
        pixelHash /= isSpecular;

        if(depth == 0 || applyRotation == true){
            if (!intersection.hit) { 
                intersection.depth = 999999; 
                intersection.normal = -realDirection; 
                intersection.position = 99999.0 * realDirection;
                material.color = NoHit(realDirection, realStart);
                intersection.object_id = -1;
            }

            output.normal = intersection.normal;
            output.depth = intersection.depth;
            output.intersection = intersection.position;
            output.albedo = material.color;
            output.object_id = intersection.object_id;
        }

        if (!intersection.hit) {
            hit_light = true;
            accumulatedColor *= NoHit(realDirection, realStart);
            break;
        }

        var diffuse: vec3<f32>;
        var newDirection: vec3<f32>;

        if(isSpecular <= material.reflectance){
            let newDirectionValue = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
            let reflected = (realDirection - 2.0 * dot(realDirection, intersection.normal) * intersection.normal);
            newDirection = normalize((1 - material.reflectance) *  newDirectionValue.output + material.reflectance * reflected);
            pixelHash = newDirectionValue.seed;

            diffuse = (max(1 - material.emittance, 0) * material.color);
        } else {
            let terminationRandom = random(pixelHash);
            pixelHash *= terminationRandom; 

            /*if (terminationRandom < russianRuleteProbability && material.emittance == 0) {
                accumulatedColor *= 1.0 / (1.0 - terminationRandom);
                break;
            }*/

            let russianP = max(accumulatedColor.x, max(accumulatedColor.y, accumulatedColor.z));
            if (terminationRandom > russianP) {
                accumulatedColor *= 1.0 / (1.0 - russianP);
                break;
            }

            let newDirectionValue = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
            newDirection = newDirectionValue.output;
            pixelHash = newDirectionValue.seed;

            let p = 1.0 / (2.0 * 3.141592653589);
            let cos_theta = dot(newDirection, intersection.normal);
            
            var BRDF = (max(1 - material.emittance, 0) * material.color) / 3.141592653589;
            diffuse = BRDF * cos_theta / p;
        }

        if(applyRotation == true){
            output.object_id = intersection.object_id;
            output.albedo = (diffuse + emittance) * fistColor;
            diffuse = vec3<f32>(1, 1, 1);
            emittance = vec3<f32>(0, 0, 0);

            applyRotation = false;
        }

        if(depth == 0) {
            output.object_id = intersection.object_id;
            output.albedo = diffuse + emittance;
            fistColor = output.albedo;
            diffuse = vec3<f32>(1, 1, 1);
            emittance = vec3<f32>(0, 0, 0);

            if(material.reflectance >= 0.35){
            //if(dot(reflected, newDirectionValue.output) > 0.9){
                applyRotation = true;
            }
        } // remove albedo from first bounce, we only want the noisy data

        accumulatedColor *= emittance + diffuse;

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

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    output.noisy_color = vec4<f32>(NoHit(direction, start), 1);
    //output.noisy_color = vec4<f32>(direction.y, 1, 1, 1);
    output.albedo = vec3<f32>(1);

    /*if (!hit_octree(start, direction, inputTreeParts[0])) {
        output.albedo = NoHit(direction, start);
    } else {
        for(var i = 0; i < 11; i++){
            if(hit_octree(start, direction, inputTreeParts[i])){
                output.albedo = vec3<f32>(f32(i) / 11, 1, 0);
            }
        }
    }*/

    return output;
}*/

/*fn getTemporalData(
    pixel: vec2<f32>
) -> TemportalData {
    return temporalBuffer[u32(pixel.x + pixel.y * inputData.resolution.x)];
}*/

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
    pixel: vec2<f32>,
    initialPixelHash: f32, 
) -> TraceOutput {
    var pixelHash = randomVec2(initialPixelHash, pixel);

    var pixelModifier = random2Vec2(pixelHash, pixel);
    pixelHash = pixelModifier.seed;

    var realPixel = pixel + pixelModifier.output / 2;

    let direction = calculatePixelDirection(realPixel);
    let start = inputData.CameraPosition;

    var output: TraceOutput;

    //let temporalData = getTemporalData(realPixel);
    var traceOutput = RunTracer(direction, start, pixel, pixelHash);

    //traceOutput.velocity = (temporalData.rayDirection - direction).xy;

    output.pixel = traceOutput;
    output.seed = pixelHash;
    //output.temporalData = calculateTemporalData(realPixel, traceOutput, start, direction);

    return output;
}

fn isNan(num: f32) -> bool {
    return (bitcast<u32>(num) & 0x7fffffffu) > 0x7f800000u;
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

    //let index = global_invocation_id.x + global_invocation_id.y * u32(inputData.resolution.x);

    var avarageColor: vec4<f32>;
    var avarageAlbedo: vec3<f32>;
    var avarageNormal: vec3<f32>;
    var averageIntersection: vec3<f32>;
    var avarageDepth: f32;

    var maxRays: f32 = 1;
    //var maxRays: f32 = 5;
    var seed = image_history_data.totalFrames;
    var object: f32 = 0;

    for(var rayNum = 0; rayNum < i32(maxRays); rayNum++){
        let pixelData = calculatePixelColor(vec2<f32>(global_invocation_id.xy), seed);
        seed = pixelData.seed;

        avarageColor += pixelData.pixel.noisy_color;
        avarageAlbedo += pixelData.pixel.albedo;
        avarageNormal += pixelData.pixel.normal;
        avarageDepth += pixelData.pixel.depth;

        averageIntersection += pixelData.pixel.intersection;
        object = pixelData.pixel.object_id;
    }

    //imageBuffer[index] = pixelData.pixel;
    //temporalBuffer[index] = pixelData.temporalData;

    if(isNan(avarageColor.x) || isNan(avarageColor.y) || isNan(avarageColor.z) || isNan(avarageColor.w)){ return; }
    textureStore(image_color_texture, global_invocation_id.xy, avarageColor / maxRays);
    textureStore(image_albedo_texture, global_invocation_id.xy, vec4<f32>(avarageAlbedo / maxRays, 0));
    textureStore(image_normal_texture, global_invocation_id.xy, vec4<f32>(avarageNormal / maxRays, 0));
    textureStore(image_depth_texture, global_invocation_id.xy, vec4<f32>(averageIntersection / maxRays, avarageDepth / maxRays));
    textureStore(image_object_texture, global_invocation_id.xy, vec4<f32>(object, 0, 0, 0));
}