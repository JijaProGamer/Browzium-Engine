struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,
    focalLength: f32,

    CameraPosition: vec3<f32>,
    apertureSize: f32,

    CameraToWorldMatrix: mat4x4<f32>,

    tonemapmode: f32,
    gammacorrect: f32,
};

struct Triangle {
    a: vec3<f32>,
    material_index: f32,
    b: vec3<f32>,
    object_id: f32,
    c: vec3<f32>,
    padding0: f32,

    na: vec3<f32>,
    padding1: f32,
    nb: vec3<f32>,
    padding2: f32,
    nc: vec3<f32>,
    padding3: f32,

    uva: vec2<f32>,
    uvb: vec2<f32>,
    uvc: vec2<f32>,

    padding4: f32,
    padding5: f32,
};

struct Material {
    color: vec3<f32>,
    texture_layer: f32,
    
    specular_color: vec3<f32>,
    transparency: f32,

    diffuse_atlas_start: vec2<f32>,
    diffuse_atlas_extend: vec2<f32>,
    
    index_of_refraction: f32,
    reflectance: f32,
    emittance: f32,
    roughness: f32,
};

struct InputMapData {
    triangle_count: f32,
    padding0: f32,
    padding1: f32,
    padding2: f32,
    triangles: array<Triangle>,
};

struct InputLightData {
    triangle_count: f32,
    triangles: array<f32>,
};

struct Pixel {
    noisy_color: vec4<f32>,
    albedo: vec3<f32>,
    normal: vec3<f32>,
    velocity: vec2<f32>,
    depth: f32,
    object_id: f32,
    intersection: vec3<f32>,
    seed: f32,
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
@group(1) @binding(1) var<storage, read> inputLightMap: InputLightData;
@group(1) @binding(2) var<storage, read> inputMaterials: array<Material>;
@group(1) @binding(3) var<storage, read> inputTreeParts: array<TreePart>;

@group(1) @binding(4) var textureAtlas: texture_2d_array<f32>;
@group(1) @binding(5) var textureAtlasSampler: sampler;

@group(1) @binding(6) var worldTexture: texture_2d<f32>;
@group(1) @binding(7) var worldTextureSampler: sampler;

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
    position: vec3<f32>,
    uv: vec2<f32>
}

struct OctreeHitResult {
    hit: bool,
    treePart: TreePart,
}

const errorAmount = 0.00001;

fn hit_triangle(tri: Triangle, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> HitResult {
    var result: HitResult;

    /*if(!is_triangle_facing_camera(tri, ray_direction)){
        return result;
    }*/

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

    let w = 1.0 - u - v;
    result.uv = w * tri.uva + u * tri.uvb + v * tri.uvc;

    if(!is_triangle_facing_camera(tri, ray_direction)){
        result.normal = -result.normal;
    }

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

fn get_light_ray_intersection(ray_origin: vec3<f32>, ray_direction: vec3<f32>, object_needed: f32) -> HitResult {
    let epsilon = 0.01;

    var depth: f32 = 9999999;
    var result: HitResult;

    for (var i: f32 = 0; i < inputMap.triangle_count; i = i + 1) {
        let currentTriangle = inputMap.triangles[i32(i)];
        let current_result = hit_triangle(currentTriangle, ray_origin, ray_direction);

        let satisfyDepth = current_result.hit && current_result.depth < depth;
        let satisfyLightCheck = abs(depth - current_result.depth) > epsilon && (result.object_id != object_needed || current_result.object_id == object_needed);

        if(current_result.object_id > 0){
        //if (satisfyDepth || !satisfyLightCheck) {
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

    x += (x << 10u);
    x ^= ( x >>  6u ) * x;
    x += ( x <<  3u );
    x ^= ( x >> 11u ) * x * x;
    x += ( x << 15u );
    
    return x;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    return bitcast<f32>(mBits) - 1;
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
    return floatConstruct(hash(bitcast<u32>(seed)));
}

fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    return random(seed + vec.x * 0.44 - vec.y);
}

fn randomVec3(seed: f32, vec: vec3<f32>) -> f32 {
    return random(seed + vec.x * 0.44 - vec.y * vec.z);
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> Random3Vec2Output {
    var output: Random3Vec2Output;
    var seedValue = randomVec2(seed, vec);

    var outputVector = vec2<f32>(random(vec.x * seedValue), random(vec.x * seedValue)); // tap tap ingerasi
    outputVector -= vec2<f32>(0.5);
    outputVector *= 2;

    output.seed = random(outputVector.y + outputVector.x / .43145 + seed * 2.634145);
    output.output = outputVector;
    
    return output;
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> Random3Vec3Output {
    var vector = vec4<f32>(seed, vec);
    var output: Random3Vec3Output;

    vector = vector * vec4<f32>(.9898, 78.233, 43.094, 94.457);
    vector += dot(vector, vector.wzxy + 33.33);

    vector = (vector.xxyz + vector.yzzw) * vector.zywx;
    vector = vec4<f32>(random(vector.x), random(vector.y), random(vector.z), random(vector.w)); // tap tap ingerasi
    vector -= vec4<f32>(0.5);
    vector *= 2;

    output.seed = random(vector.y + vector.x - vector.z * vector.w);
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

/*fn randomPointInCircle(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var outputSeed = seed;

    var tries = 0;
    var output = random3Vec3(outputSeed, position);
    outputSeed = output.seed;
    while(dot(output.output, output.output) > 1 && tries < 10){
        outputSeed = output.seed;
        output = random3Vec3(outputSeed, position);
        tries ++;
    }

    output.output = normalize(output.output);
    output.seed = outputSeed;

    return output;
}*/

fn randomPointInCircle(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var output: Random3Vec3Output;

    let newSeed = randomVec3(seed, position);
    let u1 = random(newSeed);
    let u2 = random(u1);

    let phi = acos(2.0 * u1 - 1.0) - 3.14159265359 / 2.0;
    let lambda = 2.0 * 3.14159265359 * u2;

    let x = cos(phi) * cos(lambda);
    let y = cos(phi) * sin(lambda);
    let z = sin(phi);

    output.output = vec3<f32>(x, y, z);
    output.seed = u2;

    return output;
}

fn uvOnWorldSphere(
    direction: vec3<f32>, 
    start: vec3<f32>
) -> vec2<f32>{
    let theta = atan2(direction.x, direction.z);
    let phi = acos(direction.y);

    let u = (theta + 3.141592653) / (2.0 * 3.141592653);
    let v = phi / 3.141592653;

    return vec2<f32>(u, v);
}

fn NoHit(
    direction: vec3<f32>, 
    start: vec3<f32>
) -> vec3<f32> {
    let UV = uvOnWorldSphere(direction, start);
    return vec3<f32>(UV, 0);

    //var textureColor = textureSampleLevel(worldTexture, worldTextureSampler, UV, 1);
    //return textureColor.rgb; // later return a too
}

struct BRDFDirectionOutput {
    isSpecular: bool,
    isTransparent: bool,
    direction: vec3<f32>,
    outputHash: f32,
}

struct DirectCalculationOutput {
    color: vec3<f32>,
    direction: vec3<f32>,
    seed: f32,
    wasHit: bool,
    hit: HitResult,
}

fn RandomPointOnTriangle(
    tri: Triangle,
    rawHash: f32,
) -> vec4<f32> {
    var hash = rawHash;

    var r1 = random(hash);
    var r2 = random(r1);
    hash = r2;

    if (r1 + r2 > 1) {
        r1 = 1 - r1;
        r2 = 1 - r2;
    }

    var r3 = 1 - r1 - r2;

    var x = r1 * tri.a.x + r2 * tri.b.x + r3 * tri.c.x;
    var y = r1 * tri.a.y + r2 * tri.b.y + r3 * tri.c.y;
    var z = r1 * tri.a.z + r2 * tri.b.z + r3 * tri.c.z;

    return vec4<f32>(x, y, z, hash);
}

fn getColor(
    material: Material,
    intersection: HitResult,
) -> vec4<f32> {
    if(!intersection.hit){
        return vec4<f32>(1);
    }

    let textureCoord = material.diffuse_atlas_start + intersection.uv * material.diffuse_atlas_extend;

    var textureColor = textureSampleLevel(textureAtlas, textureAtlasSampler, textureCoord, i32(material.texture_layer), 0);
    let triangleColor = vec4<f32>(material.color, 1);

    if(material.texture_layer == -1.0){
        textureColor = vec4<f32>(1);
    }

    return triangleColor * textureColor;
}

fn CalculateDirect(
    rayPosition: vec3<f32>,
    oldIntersection: HitResult,
    rawPixelHash: f32,
) -> DirectCalculationOutput {
    var output: DirectCalculationOutput;

    var pixelHash = rawPixelHash;
    //let triIndex = u32(floor(pixelHash * inputLightMap.triangle_count));
    
    //let tri = inputMap.triangles[u32(inputLightMap.triangles[triIndex])];

    /*let tri = inputMap.triangles[u32(inputLightMap.triangles[1])];
    let lightSample = vec4<f32>((tri.a + tri.b + tri.c) / 3, pixelHash);*/

    var tri: Triangle;
    var depth: f32 = 9999999999;

    for(var i: u32 = 0; i < u32(inputLightMap.triangle_count); i++){
        let newTri = inputMap.triangles[u32(inputLightMap.triangles[i])];
        let depthPosition = rayPosition - (newTri.a + newTri.b + newTri.c) / 3;
        let newDepth = dot(depthPosition, depthPosition);
        pixelHash = random(pixelHash);

        if(depth == 9999999999 || (newDepth < depth && pixelHash < 0.5)){
            depth = newDepth;
            tri = newTri;
        }
    }

    let lightSample = RandomPointOnTriangle(tri, pixelHash);
    var hash = lightSample.w;
    //let lightSample = vec4<f32>((tri.a + tri.b + tri.c) / 3, pixelHash);

    let lightPosition = lightSample.xyz;

    var shadowRayDirection = normalize(lightPosition - rayPosition);
    //let shadowIntersection = get_light_ray_intersection(rayPosition, shadowRayDirection, tri.object_id);
    let shadowIntersection = get_ray_intersection(rayPosition, shadowRayDirection);

    if (shadowIntersection.hit && shadowIntersection.object_id == tri.object_id) {
        let material = inputMaterials[i32(tri.material_index)];

        let cos_theta = dot(-shadowRayDirection, shadowIntersection.normal);
        let brdf = (getColor(material, shadowIntersection).rgb * material.emittance) / 3.141592;
        let color = brdf * cos_theta /  (1 / (2 * 3.141592));
        output.color = color;

        output.hit = shadowIntersection;
        output.wasHit = true;
    }

    /*if(!shadowIntersection.hit || shadowIntersection.object_id != tri.object_id){
        var diffuseDirectionValue = randomPointInCircle(hash, rayPosition);
        hash = diffuseDirectionValue.seed;

        shadowRayDirection = normalize(diffuseDirectionValue.output - oldIntersection.normal);

        output.color = NoHit(rayPosition, shadowRayDirection);
        output.wasHit = true;
    }*/

    output.seed = hash;
    output.direction = shadowRayDirection;

    return output;
}

fn refract(incident: vec3<f32>,normal: vec3<f32>, eta: f32) -> vec3<f32> {
    let cosI = dot(-incident, normal);
    let sinT2 = eta * eta * (1.0 - cosI * cosI);

    if (sinT2 > 1.0) {
        return incident - 2.0 * dot(incident, normal) * normal;
    } else {
        let cosT = sqrt(1.0 - sinT2);
        return eta * incident + (eta * cosI - cosT) * normal;
    }
}

fn TransparencyDirection(
    intersection: HitResult,
    oldDirection: vec3<f32>,
    rawHash: f32,
) -> BRDFDirectionOutput {
    var output: BRDFDirectionOutput;
    var pixelHash = random(rawHash);
    let doTransparency = pixelHash < intersection.material.transparency;
    
    let eta = 1.0 / intersection.material.index_of_refraction;
    let transmittedDir = refract(oldDirection, intersection.normal, eta);
    
    output.isTransparent = doTransparency;
    output.direction = transmittedDir;
    output.outputHash = pixelHash;

    return output;
}

fn BRDFDirection(
    intersection: HitResult,
    oldDirection: vec3<f32>,
    rawHash: f32,
) -> BRDFDirectionOutput { 
    let transparencyOutput = TransparencyDirection(intersection, oldDirection, rawHash);
    var output: BRDFDirectionOutput;
    var pixelHash = random(transparencyOutput.outputHash);

    if(transparencyOutput.isTransparent){   return transparencyOutput;  }

    let doSpecular = random(pixelHash) < intersection.material.reflectance;
    
    var diffuseDirectionValue = randomPointInCircle(pixelHash, intersection.position);
    pixelHash = diffuseDirectionValue.seed;

    let reflectedDir = (oldDirection - 2.0 * dot(oldDirection, intersection.normal) * intersection.normal);
    let diffuseDirection = normalize(intersection.normal + diffuseDirectionValue.output);
    let specularDir = normalize(mix(reflectedDir, diffuseDirection, intersection.material.roughness));
    let outputDir = mix(diffuseDirection, specularDir, f32(doSpecular));

    output.isSpecular = doSpecular;
    output.direction = outputDir;
    output.outputHash = pixelHash;

    return output;
}

struct NEEStackElement {
    albedo: vec3<f32>,
    emittance: vec3<f32>,
    intersection: HitResult,
}

const maxDepth: i32 = 4;

fn RunTracer(direction: vec3<f32>, start: vec3<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    var oldMaterial: Material;
    var intersection: HitResult;
    var realDirection = direction;
    var realStart = start;

    var pixelHash = rawPixelHash;
    var hit_light = false;

    var gatherDenoisingData = true;
    var wasReflection = false;

    var emittance: vec3<f32>;

    var stackLength: i32;
    var stack: array<NEEStackElement, maxDepth>;

    for (var depth: i32 = 0; depth <= maxDepth; depth = depth + 1) {
        if (!intersection.hit && depth > 0) {
            break;
        }

        var stackElement: NEEStackElement;

        intersection = get_ray_intersection(realStart, realDirection);
        var material = intersection.material;

        if(gatherDenoisingData){
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
            output.object_id = intersection.object_id;
            output.albedo = getColor(material, intersection).rgb;
            gatherDenoisingData = false;

            if(wasReflection){
                output.albedo *= oldMaterial.color;
            }
        }

        if (!intersection.hit) {
            let emittance = NoHit(realDirection, realStart);

            var stackElement: NEEStackElement;
            stackElement.emittance = emittance;
            stackElement.albedo = vec3<f32>(1, 1, 1);

            stack[depth] = stackElement;
            break;
        }

        let BRDFDirectionValue = BRDFDirection(intersection, realDirection, pixelHash);
        pixelHash = BRDFDirectionValue.outputHash;

        var directIncoming = CalculateDirect(intersection.position, intersection, pixelHash);
        var indirectIncoming = getColor(material, intersection).rgb * material.emittance;

        let emittance = indirectIncoming + directIncoming.color;
        pixelHash = directIncoming.seed;


        stackElement.emittance = emittance;
        stackElement.albedo = getColor(material, intersection).rgb;
        stack[depth] = stackElement;

        gatherDenoisingData = depth == 0 && (BRDFDirectionValue.isSpecular || BRDFDirectionValue.isTransparent);
        wasReflection = gatherDenoisingData;

        realStart = intersection.position;
        realDirection = BRDFDirectionValue.direction;
        oldMaterial = material;
        stackLength = depth;
    }

    var incomingLight = vec3<f32>(0);
    var rayColor = vec3<f32>(1);

    for(var stackDepth: i32 = stackLength; stackDepth >= 0; stackDepth = stackDepth - 1){
        let stackElement = stack[stackDepth];

        incomingLight += stackElement.emittance * rayColor;
        rayColor *= stackElement.albedo;

        if(stackDepth == 1) {
            incomingLight /= 2;
        }
    }

    output.noisy_color = vec4<f32>(incomingLight, 0);
    
    output.seed = pixelHash;
    return output;
}

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    var oldMaterial: Material;
    var intersection: HitResult;
    var realDirection = direction;
    var realStart = start;

    var incomingLight = vec3<f32>(0);
    var rayColor = vec3<f32>(1);

    var pixelHash = rawPixelHash;
    var hit_light = false;
    var depth: i32 = 0;

    var gatherDenoisingData = true;
    var wasReflection = false;

    var emittance: vec3<f32>;

    for (; depth <= maxDepth; depth = depth + 1) {
        if (!intersection.hit && depth > 0) {
            break;
        }

        intersection = get_ray_intersection(realStart, realDirection);
        var material = intersection.material;

        if(gatherDenoisingData){
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
            output.object_id = intersection.object_id;
            output.albedo = getColor(material, intersection).rgb;
            gatherDenoisingData = false;

            if(wasReflection){
                output.albedo *= oldMaterial.color;
            }
        }

        if (!intersection.hit) {
            emittance = NoHit(realDirection, realStart);

            incomingLight += rayColor * emittance;
            rayColor *= emittance;

            break;
        }

        let BRDFDirectionValue = BRDFDirection(intersection, realDirection, pixelHash);
        var reflected = /*max(1 - material.emittance, 0) **/ getColor(material, intersection).rgb;
        pixelHash = BRDFDirectionValue.outputHash;

        //var directIncoming = CalculateDirect(intersection.position, intersection, pixelHash);
        var indirectIncoming = getColor(material, intersection).rgb * material.emittance;
        //var weightIncoming = 1.0; 
        //if(depth == 1) {weightIncoming = 0.5;}

        emittance = indirectIncoming;

        //emittance =  weightIncoming * (indirectIncoming + directIncoming.color);
        //emittance = directIncoming.color;
        //pixelHash = directIncoming.seed;

        gatherDenoisingData = depth == 0 && (BRDFDirectionValue.isSpecular || BRDFDirectionValue.isTransparent);
        wasReflection = gatherDenoisingData;

        incomingLight += emittance * rayColor;

        //if(!gatherDenoisingData){
            rayColor *= reflected;
        //}

        realStart = intersection.position;
        realDirection = BRDFDirectionValue.direction;
        oldMaterial = material;
    }

    output.noisy_color = vec4<f32>(incomingLight, 0);
    
    output.seed = pixelHash;
    return output;
}*/

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    output.noisy_color = vec4<f32>(1);
    output.albedo = vec3<f32>(0);

    let intersection = get_ray_intersection(start, direction);
    var material = intersection.material;

    if (!intersection.hit) {
        output.albedo = NoHit(direction, start);
        return output;
    }

    var directIncoming = CalculateDirect(intersection.position, intersection, rawPixelHash);

    if(directIncoming.wasHit){
        output.albedo = getColor(material, intersection).rgb * directIncoming.color; // dot(direction, directIncoming.direction);
    }

    if(material.emittance > 0){
        output.albedo = getColor(material, intersection).rgb * material.emittance;
    }

    output.seed = directIncoming.seed;

    return output;
}*/

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    if (!hit_octree(start, direction, inputTreeParts[0])) {
        output.noisy_color = vec4<f32>(1);
        output.albedo = NoHit(direction, start);
    } else {
        var maxChildren = 1;

        var stack: array<TreePart, 64>;
        var stackIndex: i32 = 0;

        stack[stackIndex] = inputTreeParts[0];
        stackIndex++;

        while (stackIndex > 0) {
            stackIndex--;
            let currentBox = stack[stackIndex];

            let hit = hit_octree(start, direction, currentBox);

            if (hit && currentBox.child1 > -1.0) {
                maxChildren += 2;

                stack[stackIndex] = inputTreeParts[i32(currentBox.child1)];
                stackIndex++;
                stack[stackIndex] = inputTreeParts[i32(currentBox.child2)];
                stackIndex++;
            }
        }

        output.noisy_color = vec4<f32>(1);
        for(var i = 0; i < maxChildren; i++){
            if(hit_octree(start, direction, inputTreeParts[i])){
                output.albedo = vec3<f32>(f32(i) / f32(maxChildren), 1, 0);
            }
        }
    }

    return output;
}*/

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    output.noisy_color = vec4<f32>(1);

    //var random = random3Vec3(rawPixelHash, vec3<f32>(pixel, 50));
    //output.albedo = vec3<f32>((random.output.x + 1) / 2, (random.output.y + 1) / 2, (random.output.z + 1) / 2);

    var random1 = random(pixel.x + pixel.y * inputData.resolution.x);
    var random2 = random(random1);
    var random3 = random(random2);

    output.albedo = vec3<f32>(random1, random2, random3);

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

struct DOFOutput
{
    start: vec3<f32>,
    direction: vec3<f32>,
    pixelHash: f32,
}

fn applyDOF(
    direction: vec3<f32>,
    pixel: vec2<f32>,
    pixelHash: f32,
) -> DOFOutput {
    var output: DOFOutput;
    let focalPoint = inputData.CameraPosition + direction * inputData.focalLength;
    let randomAperture = random2Vec2(pixelHash, pixel);
    let apertureShift = randomAperture.output * inputData.apertureSize;

    output.start = inputData.CameraPosition + vec3<f32>(apertureShift.x, apertureShift.y, 0.0);
    output.direction = normalize(focalPoint - output.start);
    output.pixelHash = randomAperture.seed;

    return output;
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
    //var pixelHash = randomVec2(initialPixelHash, pixel);
    //var pixelModifier = random2Vec2(/*pixelHash*/initialPixelHash, pixel);

    //var realPixel = pixel + (pixelModifier.output + vec2<f32>(1, 1)) / 2;
    //let DOF = applyDOF(calculatePixelDirection(realPixel), realPixel, pixelModifier.seed);
    let DOF = applyDOF(calculatePixelDirection(pixel), pixel, initialPixelHash);
    
    let direction = DOF.direction;
    let start = DOF.start;

    var output: TraceOutput;

    //let temporalData = getTemporalData(realPixel);
    var traceOutput = RunTracer(direction, start, DOF.pixelHash);

    //traceOutput.velocity = (temporalData.rayDirection - direction).xy;

    output.pixel = traceOutput;
    output.seed = traceOutput.seed;
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
    var raysDone: f32 = 0;
    //var maxRays: f32 = 5;
    var seed = image_history_data.totalFrames;
    var object: f32 = 0;

    for(var rayNum = 0; rayNum < i32(maxRays); rayNum++){
        let pixelData = calculatePixelColor(vec2<f32>(global_invocation_id.xy), seed);
        seed = pixelData.seed;
        if(isNan(pixelData.pixel.noisy_color.x) || isNan(pixelData.pixel.noisy_color.y) || isNan(pixelData.pixel.noisy_color.z) || isNan(pixelData.pixel.noisy_color.w)){ continue; }

        avarageColor += pixelData.pixel.noisy_color;
        avarageAlbedo += pixelData.pixel.albedo;
        avarageNormal += pixelData.pixel.normal;
        avarageDepth += pixelData.pixel.depth;

        raysDone += 1;
        averageIntersection += pixelData.pixel.intersection;
        object = pixelData.pixel.object_id;
    }

    //imageBuffer[index] = pixelData.pixel;
    //temporalBuffer[index] = pixelData.temporalData;

    if(raysDone == 0) {return; }
    if(isNan(avarageColor.x) || isNan(avarageColor.y) || isNan(avarageColor.z) || isNan(avarageColor.w)){ return; }

    textureStore(image_color_texture, global_invocation_id.xy, avarageColor / raysDone);
    textureStore(image_albedo_texture, global_invocation_id.xy, vec4<f32>(avarageAlbedo / raysDone, 0));
    textureStore(image_normal_texture, global_invocation_id.xy, vec4<f32>(avarageNormal / raysDone, 0));
    textureStore(image_depth_texture, global_invocation_id.xy, vec4<f32>(averageIntersection / raysDone, avarageDepth / raysDone));
    textureStore(image_object_texture, global_invocation_id.xy, vec4<f32>(object, 0, 0, 0));
}