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
    depth: f32,
    object_id: f32,

    intersection: vec3<f32>,

    velocity: vec2<f32>,
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

    tri: Triangle,
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

    if(!is_triangle_facing_camera(ray_direction, result.normal)){
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

fn get_ray_intersection(ray_origin: vec3<f32>, oldId: f32, ray_direction: vec3<f32>) -> HitResult {
    var depth: f32 = 9999999;
    var result: HitResult;

    result.object_id = -1;

    for (var i: f32 = 0; i < inputMap.triangle_count; i = i + 1) {
        let currentTriangle = inputMap.triangles[i32(i)];
        let current_result = hit_triangle(currentTriangle, ray_origin, ray_direction);

        if (current_result.hit && current_result.depth < depth && i != oldId) {
            result = current_result;
            depth = result.depth;

            result.material = inputMaterials[i32(currentTriangle.material_index)];
            result.object_id = currentTriangle.object_id;
            result.tri = currentTriangle;
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
            result.tri = currentTriangle;
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

fn is_triangle_facing_camera(ray_direction: vec3<f32>, normal: vec3<f32>) -> bool {    
    return -dot(normal, ray_direction) >= 0;
}
// PCG Hash
// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
fn hash(input: u32) -> u32 {
    let state = input * 747796405u + 2891336453u;
    let word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    return bitcast<f32>(mBits) - 1;
}

fn random(seed: ptr<function,f32>) -> f32 {
    *seed = floatConstruct(hash(bitcast<u32>(*seed)));
    return *seed;
}

/*fn randomNormalDistribution(seed: f32) -> vec2<f32> {
    let seed1 = random(seed);
    let seed2 = random(seed1);

    let theta = 2 * 3.1415926 * seed1;
    let rho = sqrt(-2 * log(seed2));
    
    return vec2<f32>(rho * cos(theta), random(seed2));
}*/

fn randomFromVec2(seed: ptr<function,f32>, vec: vec2<f32>) -> f32 {
    *seed += dot(vec, vec2<f32>(43.321312, 2.421333341));
    random(seed);

    return *seed;
}

fn randomFromVec3(seed: ptr<function,f32>, vec: vec3<f32>) -> f32 {
    *seed += dot(vec, vec3<f32>(31.85175124, 32.2415625, -50.23123));
    random(seed);

    return *seed;
}

fn randomVec2FromVec2(seed: ptr<function,f32>, vec: vec2<f32>) -> vec2<f32> {
    randomFromVec2(seed, vec);

    var x = random(seed);
    var y = random(seed);

    return vec2<f32>((x - 0.5) * 2, (y - 0.5) * 2);
}

fn randomVec3FromVec3(seed: ptr<function,f32>, vec: vec3<f32>) -> vec3<f32> {
    randomFromVec3(seed, vec);

    var x = random(seed);
    var y = random(seed);
    var z = random(seed);

    return vec3<f32>((x - 0.5) * 2, (y - 0.5) * 2, (z - 0.5) * 2);
}

fn randomPoint(seed: ptr<function,f32>, position: vec3<f32>) -> vec3<f32> {
    return normalize(randomVec3FromVec3(seed, position));
}

fn randomPoint2(seed: ptr<function,f32>, position: vec2<f32>) -> vec2<f32> {
    return normalize(randomVec2FromVec2(seed, position));
}

fn randomPointOnCircle(seed: ptr<function,f32>, position: vec2<f32>) -> vec2<f32> {
    var tries = 0;
    var output = randomVec2FromVec2(seed, position);

    while(dot(output, output) > 1 && tries < 10){
        output = randomVec2FromVec2(seed, position);
        tries ++;
    }

    return normalize(output);
}

fn randomPointOnSphere(seed: ptr<function,f32>, position: vec3<f32>) -> vec3<f32> {
    var tries = 0;
    var output = randomVec3FromVec3(seed, position);

    while(dot(output, output) > 1 && tries < 10){
        output = randomVec3FromVec3(seed, position);
        tries ++;
    }

    return normalize(output);
}

/*fn randomPointInCircle(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var output: Random3Vec3Output;

    let x = randomNormalDistribution(seed);
    let y = randomNormalDistribution(x.y);
    let z = randomNormalDistribution(y.y);

    output.output = normalize(vec3<f32>(x.x, y.x, z.x));
    output.seed = z.y;

    return output;
}*/

/*fn randomPointInCircle(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
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
}*/

const PI = 3.141592653589793238462643383279502884;

fn uvOnWorldSphere(
    direction: vec3<f32>, 
    start: vec3<f32>
) -> vec2<f32>{
    let theta = atan2(direction.x, direction.z);
    let phi = acos(direction.y);

    let u = (theta + PI) / (2.0 * PI);
    let v = phi / PI;

    return vec2<f32>(u, v);
}

fn NoHit(
    direction: vec3<f32>, 
    start: vec3<f32>
) -> vec3<f32> {
    let UV = uvOnWorldSphere(direction, start);
    return vec3<f32>(UV, 0);

    /*if(UV.y < 0.5) {
        return vec3<f32>(0, 0, 0);
    }  else {
        return vec3<f32>(1, 1, 1);
    }*/
    //return vec3<f32>(0);

    //var textureColor = textureSampleLevel(worldTexture, worldTextureSampler, UV, 1);
    //return textureColor.rgb; // later return a too
}

struct BRDFDirectionOutput {
    isSpecular: bool,
    isTransparent: bool,
    direction: vec3<f32>,
}


fn RandomPointOnTriangle(
    tri: Triangle,
    seed: ptr<function,f32>,
) -> vec3<f32> {
    var r1 = random(seed);
    var r2 = random(seed);

    if (r1 + r2 > 1) {
        r1 = 1 - r1;
        r2 = 1 - r2;
    }

    var r3 = 1 - r1 - r2;

    var x = r1 * tri.a.x + r2 * tri.b.x + r3 * tri.c.x;
    var y = r1 * tri.a.y + r2 * tri.b.y + r3 * tri.c.y;
    var z = r1 * tri.a.z + r2 * tri.b.z + r3 * tri.c.z;

    return vec3<f32>(x, y, z);
}

fn getTriangleAlbedo(
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

fn Le(
    material: Material,
    intersection: HitResult,
) -> vec4<f32> {
    let triangleColor = vec4<f32>(material.color, 1);
    return triangleColor * material.emittance;
}

fn Eval_BRDF(
    incoming: vec3<f32>,
    outgoing: vec3<f32>
) -> f32 {
    // Returns the weight of the BRDF
    // Lambertian Diffuse only for now

    return 1 / PI;
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
    seed: ptr<function,f32>,
) -> BRDFDirectionOutput {
    var output: BRDFDirectionOutput;

    let doTransparency = random(seed) < intersection.material.transparency;
    
    let eta = 1.0 / intersection.material.index_of_refraction;
    let transmittedDir = refract(oldDirection, intersection.normal, eta);
    
    output.isTransparent = doTransparency;
    output.direction = transmittedDir;

    return output;
}

fn BRDFDirection(
    intersection: HitResult,
    oldDirection: vec3<f32>,
    seed: ptr<function,f32>,
) -> BRDFDirectionOutput { 
    let transparencyOutput = TransparencyDirection(intersection, oldDirection, seed);
    if(transparencyOutput.isTransparent){   return transparencyOutput;  }

    var output: BRDFDirectionOutput;
    random(seed);

    let doSpecular = random(seed) < intersection.material.reflectance;

    let reflectedDir = reflect(oldDirection, intersection.normal);
    let diffuseDirection = normalize(intersection.normal + randomPointOnSphere(seed, intersection.position));

    let specularDir = normalize(mix(reflectedDir, diffuseDirection, intersection.material.roughness));

    let outputDir = mix(diffuseDirection, specularDir, f32(doSpecular));

    output.isSpecular = doSpecular;
    output.direction = outputDir;

    return output;
}

const maxDepth: i32 = 5;

// NEE
fn RunTracer(_direction: vec3<f32>, _start: vec3<f32>, seed: ptr<function,f32>) -> Pixel {
    var output: Pixel;

    var oldMaterial: Material;
    var intersection: HitResult;
    var intersectionObject: f32 = -1;
    var direction = _direction;
    var start = _start;

    var gatherDenoisingData = true;
    var wasReflection = false;

    var incomingLight = vec3<f32>(0);
    var throughput = vec3<f32>(1);

    for (var depth: i32 = 0; depth <= maxDepth; depth = depth + 1) {
        // Intersection

        intersection = get_ray_intersection(start, intersectionObject, direction);
        intersectionObject = intersection.object_id;
        let tri = intersection.tri;
        var material = intersection.material;

        // Get denoising data

        if(gatherDenoisingData){
            if (!intersection.hit) { 
                intersection.depth = 999999; 
                intersection.normal = -direction; 
                intersection.position = 99999.0 * direction;
                material.color = NoHit(direction, start);
                intersection.object_id = -1;
            }

            output.normal = intersection.normal;
            output.depth = intersection.depth;
            output.intersection = intersection.position;
            output.object_id = intersection.object_id;
            output.albedo = getTriangleAlbedo(material, intersection).rgb;
            gatherDenoisingData = false;

            if(wasReflection){
                output.albedo *= oldMaterial.color;
            }
        }

        // If hit sky

        if (!intersection.hit) {
            let emittedLight = NoHit(direction, start);

            incomingLight += emittedLight * throughput;
            break;
        }

        //////////  [[  Path tracing  ]] \\\\\\\\\\\\

        let BRDFDirectionValue = BRDFDirection(intersection, direction, seed);

        /////              [[ Light sampling ]]            \\\\\\\

        //////// step 1 and 2, and 3 in the if check
        let lightIndex = u32(floor(random(seed) * inputLightMap.triangle_count));
        let lightTri = inputMap.triangles[u32(inputLightMap.triangles[lightIndex])];
        let lightArea = 0.5 * length(cross(lightTri.b - lightTri.a, lightTri.c - lightTri.a));
        let lightPosition = RandomPointOnTriangle(lightTri, seed);

        let unormalizedShadowRayDirection = lightPosition - intersection.position;
        let r = length(unormalizedShadowRayDirection);
        let shadowRayDirection = unormalizedShadowRayDirection / r;

        let shadowIntersection = get_ray_intersection(intersection.position + shadowRayDirection * 0.001, intersection.object_id, shadowRayDirection);
        let lightMaterial = shadowIntersection.material;

        let n_x = intersection.normal;
        let n_y = shadowIntersection.normal;

        if (shadowIntersection.hit && shadowIntersection.object_id == lightTri.object_id) {
            let G = abs(dot(n_x, shadowRayDirection) * dot(n_y, shadowRayDirection)) / (r * r);
            let b = Eval_BRDF(direction, shadowRayDirection);

            incomingLight += throughput * inputLightMap.triangle_count * lightArea * b * G * Le(lightMaterial, shadowIntersection).rgb;
        }

        /////// step 4 and 5
        
        let cosTheta = abs(dot(n_x, BRDFDirectionValue.direction));
        let sinTheta = sqrt(1 - pow(cosTheta,2));
        let p = (cosTheta * sinTheta) / PI;

        throughput *= getTriangleAlbedo(material, intersection).rgb *
                     Eval_BRDF(direction, BRDFDirectionValue.direction) 
                     * cosTheta * sinTheta / p;

        // Set variables for next bounce

        gatherDenoisingData = depth == 0 && (BRDFDirectionValue.isSpecular || BRDFDirectionValue.isTransparent);
        wasReflection = gatherDenoisingData;

        start = intersection.position + BRDFDirectionValue.direction * 0.001;
        direction = BRDFDirectionValue.direction;
        oldMaterial = material;
    }

    output.noisy_color = vec4<f32>(incomingLight, 0);
    
    return output;
}

// Basic
/*fn RunTracer(_direction: vec3<f32>, _start: vec3<f32>, seed: ptr<function,f32>) -> Pixel {
    var output: Pixel;

    var oldMaterial: Material;
    var intersection: HitResult;
    var intersectionObject: f32 = -1;
    var direction = _direction;
    var start = _start;

    var gatherDenoisingData = true;
    var wasReflection = false;

    var incomingLight = vec3<f32>(0);
    var throughput = vec3<f32>(1);

    for (var depth: i32 = 0; depth <= maxDepth; depth = depth + 1) {
        // Intersection

        intersection = get_ray_intersection(start, intersectionObject, direction);
        intersectionObject = intersection.object_id;
        let tri = intersection.tri;
        var material = intersection.material;

        // Get denoising data

        if(gatherDenoisingData){
            if (!intersection.hit) { 
                intersection.depth = 999999; 
                intersection.normal = -direction; 
                intersection.position = 99999.0 * direction;
                material.color = NoHit(direction, start);
                intersection.object_id = -1;
            }

            output.normal = intersection.normal;
            output.depth = intersection.depth;
            output.intersection = intersection.position;
            output.object_id = intersection.object_id;
            output.albedo = getTriangleAlbedo(material, intersection).rgb;
            gatherDenoisingData = false;

            if(wasReflection){
                output.albedo *= oldMaterial.color;
            }
        }

        // If hit sky

        if (!intersection.hit) {
            let emittedLight = NoHit(direction, start);

            incomingLight += emittedLight * throughput;
            break;
        }

        //////////  [[  Path tracing  ]] \\\\\\\\\\\\

        let emittedLight = Le(material, intersection);
        incomingLight += emittedLight.xyz * throughput;
        throughput *= getTriangleAlbedo(material, intersection).xyz;

        // Set variables for next bounce

        let BRDFDirectionValue = BRDFDirection(intersection, direction, seed);

        gatherDenoisingData = depth == 0 && (BRDFDirectionValue.isSpecular || BRDFDirectionValue.isTransparent);
        wasReflection = gatherDenoisingData;

        start = intersection.position + BRDFDirectionValue.direction * 0.001;
        direction = BRDFDirectionValue.direction;
        oldMaterial = material;
    }

    output.noisy_color = vec4<f32>(incomingLight, 0);
    
    return output;
}*/

// Direct light only
/*fn RunTracer(_direction: vec3<f32>, _start: vec3<f32>, seed: ptr<function,f32>) -> Pixel {
    var output: Pixel;

    var intersection: HitResult;
    var direction = _direction;
    var start = _start;

    var gatherDenoisingData = true;
    var wasReflection = false;

    intersection = get_ray_intersection(start, -1, direction);
    let tri = intersection.tri;
    var material = intersection.material;

    var incomingLight = vec3<f32>(1);
    if(!intersection.hit){
        intersection.depth = 999999; 
        intersection.normal = -direction; 
        intersection.position = 99999.0 * direction;
        intersection.object_id = -1;

        output.noisy_color = vec4<f32>(NoHit(direction, start), 1);
    }

    output.normal = intersection.normal;
    output.depth = intersection.depth;
    output.intersection = intersection.position;
    output.object_id = intersection.object_id;
    output.albedo = vec3<f32>(1, 1, 1);

    if(!intersection.hit){
        return output;
    }

    /////              [[ Light sampling ]]            \\\\\\\

    //////// step 1 and 2, and 3 in the if check
    let lightIndex = u32(floor(random(seed) * inputLightMap.triangle_count));
    let lightTri = inputMap.triangles[u32(inputLightMap.triangles[lightIndex])];
    let lightPosition = RandomPointOnTriangle(lightTri, seed);

    let unormalizedShadowRayDirection = lightPosition - intersection.position;
    let r = length(unormalizedShadowRayDirection);
    let shadowRayDirection = unormalizedShadowRayDirection / r;

    let shadowIntersection = get_ray_intersection(intersection.position + shadowRayDirection * 0.1, intersection.object_id, shadowRayDirection);
    let lightMaterial = shadowIntersection.material;

    if (shadowIntersection.hit && shadowIntersection.object_id == lightTri.object_id) {
        let color = getTriangleAlbedo(material, intersection).rgb * Le(lightMaterial, shadowIntersection).rgb;
            
        output.noisy_color = vec4<f32>(color, 1);
    }
    
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
}

fn applyDOF(
    direction: vec3<f32>,
    pixel: vec2<f32>,
    seed: ptr<function,f32>,
) -> DOFOutput {
    var output: DOFOutput;
    let focalPoint = inputData.CameraPosition + direction * inputData.focalLength;
    let randomAperture = randomVec2FromVec2(seed, pixel);
    let apertureShift = randomAperture * inputData.apertureSize;

    output.start = inputData.CameraPosition + vec3<f32>(apertureShift.x, apertureShift.y, 0.0);
    output.direction = normalize(focalPoint - output.start);

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
    seed: ptr<function,f32>, 
) -> TraceOutput {
    let pixelModifier = randomPointOnCircle(seed, pixel);
    var realPixel = pixel + (pixelModifier + vec2<f32>(1, 1)) / 2;
    let DOF = applyDOF(calculatePixelDirection(realPixel), realPixel, seed);
    
    let direction = DOF.direction;
    let start = DOF.start;

    var output: TraceOutput;

    //let temporalData = getTemporalData(realPixel);
    var traceOutput = RunTracer(direction, start, seed);

    //traceOutput.velocity = (temporalData.rayDirection - direction).xy;

    output.pixel = traceOutput;
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
    //var maxRays: f32 = 3;
    var seed = image_history_data.totalFrames;
    var object: f32 = 0;

    for(var rayNum = 0; rayNum < i32(maxRays); rayNum++){
        let pixelData = calculatePixelColor(vec2<f32>(global_invocation_id.xy), &seed);
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

    if(raysDone == 0) {
        textureStore(image_color_texture, global_invocation_id.xy, vec4<f32>(0.2, 1, 0.5, 1));
        return;
    }

    textureStore(image_color_texture, global_invocation_id.xy, avarageColor / raysDone);
    textureStore(image_albedo_texture, global_invocation_id.xy, vec4<f32>(avarageAlbedo / raysDone, 0));
    textureStore(image_normal_texture, global_invocation_id.xy, vec4<f32>(avarageNormal / raysDone, 0));
    textureStore(image_depth_texture, global_invocation_id.xy, vec4<f32>(averageIntersection / raysDone, avarageDepth / raysDone));
    textureStore(image_object_texture, global_invocation_id.xy, vec4<f32>(object, 0, 0, 0));
}