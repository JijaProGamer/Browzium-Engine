struct InputGlobalData {
    resolution: vec2<f32>,
    fov: f32,

    padding0: f32,
    CameraPosition: vec3<f32>,

    padding1: f32,
    CameraToWorldMatrix: mat4x4<f32>,

    antialias: f32,
    gammacorrect: f32,
    frame: f32,
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
    padding2: f32,
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
    normal: vec3<f32>,
    velocity: vec2<f32>,
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

@group(0) @binding(0) var<storage, read> inputData: InputGlobalData;

@group(1) @binding(0) var<storage, read> inputMap: InputMapData;
@group(1) @binding(1) var<storage, read> inputMaterials: array<Material>;
@group(1) @binding(2) var<storage, read> inputTreeParts: array<TreePart>;

@group(2) @binding(0) var image_color_texture: texture_storage_2d<rgba8unorm, write>;
@group(2) @binding(1) var image_color_texture_read: texture_2d<f32>;
@group(2) @binding(2) var<storage, read_write> temporalBuffer: array<TemportalData>;

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

fn hit_triangle(tri: Triangle, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> HitResult {
    /*if(!is_triangle_facing_camera(tri, ray_direction)){
        return -1;
    }*/

    var result: HitResult;

    let edge1 = tri.b - tri.a;
    let edge2 = tri.c - tri.a;
    let h = cross(ray_direction, edge2);
    let a = dot(edge1, h);

    if (a > -0.00001 && a < 0.00001) {
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

    if(t < 0.00001){
        return result;
    }

    result.hit = true;
    result.depth = t;
    result.normal = normalize((1.0 - u - v) * tri.na + u * tri.nb + v * tri.nc);
    result.position = ray_origin + ray_direction * t;

    return result;
}

fn hit_octree(ray_origin: vec3<f32>, ray_direction: vec3<f32>, box: TreePart) -> bool {
    let invDir = vec3<f32>(1.0 / ray_direction.x, 1.0 / ray_direction.y, 1.0 / ray_direction.z);

    let t1 = (box.center.x - box.halfSize - ray_origin.x) * invDir.x;
    let t2 = (box.center.x + box.halfSize - ray_origin.x) * invDir.x;
    let t3 = (box.center.y - box.halfSize - ray_origin.y) * invDir.y;
    let t4 = (box.center.y + box.halfSize - ray_origin.y) * invDir.y;
    let t5 = (box.center.z - box.halfSize - ray_origin.z) * invDir.z;
    let t6 = (box.center.z + box.halfSize - ray_origin.z) * invDir.z;

    let tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    let tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6));

    return tmax >= max(0.0, tmin);
}

/*fn get_octree_hit(ray_origin: vec3<f32>, ray_direction: vec3<f32>, box: TreePart) -> OctreeHitResult {
    var result: OctreeHitResult;
    var currentCheck = box;

    while(true){
        if(currentCheck.children[0] == -1){
            break;
        }

        result.hit = true;
        result.treePart = currentCheck;

        //break;
        for(var i = 0; i < 8; i++){
            let childIndex = currentCheck.children[i];
            let child = inputTreeParts[u32(childIndex)];

            if(hit_octree(ray_origin, ray_direction, child)){
                currentCheck = child;
                //break;
            }
        }
    }

    return result;
}*/

fn get_octree_hit(ray_origin: vec3<f32>, ray_direction: vec3<f32>, box: TreePart) -> OctreeHitResult {
    var result: OctreeHitResult;
    var stack: array<TreePart, 64>;
    var stackIndex: i32 = 0;

    stack[stackIndex] = box;
    stackIndex++;

    while (stackIndex > 0) {
        stackIndex--;
        let currentBox = stack[stackIndex];

        let hit = hit_octree(ray_origin, ray_direction, currentBox);

        if (hit) {
            result.hit = true;
            result.treePart = currentBox;

            if (currentBox.children[0] == -1.0) {
                return result;
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
}

fn get_ray_intersection(ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> HitResult {
    var depth: f32 = 9999999;
    var result: HitResult;

    /*let octreeHit = get_octree_hit(ray_origin, ray_direction, inputTreeParts[0]);

    if (!octreeHit.hit) {
        return result;
    }

    for (var i: i32 = 0; i < 16; i = i + 1) {
        let triIndex = octreeHit.treePart.triangles[i];
        if (triIndex == -1) {
            break;
        }

        let currentTriangle = inputMap.triangles[i32(triIndex)];
        let current_result = hit_triangle(currentTriangle, ray_origin, ray_direction);

        if (current_result.hit && current_result.depth < depth) {
            result = current_result;
            depth = result.depth;
            result.material = inputMaterials[i32(currentTriangle.material_index)];
        }
    }*/

    /*for(var j = 0; j < 17; j++){
        let octreeHit = inputTreeParts[j];
        
        for(var i = 0; i < 16; i++){
            let triIndex = octreeHit.triangles[i];
            if (triIndex == -1) {
                break;
            }

            let currentTriangle = inputMap.triangles[i32(triIndex)];
            let current_result = hit_triangle(currentTriangle, ray_origin, ray_direction);

            if (current_result.hit && current_result.depth < depth) {
                result = current_result;
                depth = result.depth;
                result.material = inputMaterials[i32(currentTriangle.material_index)];
            }
        }
    }*/

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

fn is_triangle_facing_camera(tri: Triangle, ray_direction: vec3<f32>) -> bool {
    let dotProductA = dot(tri.na, ray_direction);
    let dotProductB = dot(tri.nb, ray_direction);
    let dotProductC = dot(tri.nc, ray_direction);
    
    return dotProductA < 0.0 && dotProductB < 0.0 && dotProductC < 0.0;
}
fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    var vector = vec3<f32>(seed, vec);

    vector  = fract(vector * .1031);
    vector += dot(vector, vector.zyx + 31.32);
    return fract((vector.x + vector.y) * vector.z);
}

fn randomVec3(seed: f32, vec: vec3<f32>) -> f32 {
    var vector = vec4<f32>(seed, vec);

    vector = fract(vector * .1031);
    vector += dot(vector, vector.wzyx + 31.32);
    return fract((vector.x + vector.y) * vector.z * vector.w);
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> vec3<f32> {
    var vector = vec4<f32>(seed, vec);

    vector = fract(vector * vec4(.1031, .1030, 0.0973, .1099));
    vector += dot(vector, vector.wzxy+33.33);
    vector = fract((vector.xxyz+vector.yzzw)*vector.zywx);

    return vector.wxz * vector.y;
}

fn randomPoint(seed: f32, position: vec3<f32>) -> vec3<f32>{
    return normalize(random3Vec3(seed, position));
}

fn randomPointInHemisphere(seed: f32, normal: vec3<f32>, position: vec3<f32>) -> vec3<f32> {
    var randomVec = normalize(random3Vec3(seed, position));

    if(dot(randomVec, normal) < 0){
        return -randomVec;
    }

    return randomVec;
}

fn NoHit(
    direction: vec3<f32>, 
    start: vec3<f32>
) -> vec4<f32> {
    let a = 0.5 * (direction.y + 1.0);

    let White = vec3<f32>(0.8, 0.8, 0.8);
    let Blue = vec3<f32>(0.15, 0.3, 0.9);

    return vec4<f32>((0.7-a) * White + (a + 0.3) * Blue, 1);
}

fn Hit(
    intersection: HitResult,
) -> vec4<f32>{
    var output: vec3<f32>;
    /*let distance = min(0.35, depth / 25);

    output.r = intersection.material.color.x - distance;
    output.g = intersection.material.color.y - distance;
    output.b = intersection.material.color.z - distance;

    return output;*/

    output = intersection.material.color;

    return vec4<f32>(output, 1);
}

fn RunTracer(direction: vec3<f32>, start: vec3<f32>) -> Pixel {
    var output: Pixel;

    /*var hit = false;

    for(var i = 1; i < 25; i++){
        if(hit_octree(start, direction, inputTreeParts[i])){
            output.noisy_color.r = (f32(i) + 1) / 200;
            output.noisy_color.g = 0;
            output.noisy_color.b = (f32(i) + 1) / 200;
            hit = true;
        }
    }

    if(!hit){
        output.noisy_color = NoHit(direction, start);
    }

    return output;*/

    /*var intersection = get_ray_intersection(start, direction);
    var depth = intersection.depth;

    while(intersection.material.reflectance > 0){
        //let newDirection = direction - 2.0 * dot(direction, intersection.normal) * intersection.normal;
        let newDirection = randomPointInHemisphere(inputData.frame, intersection.normal, intersection.position);

        intersection = get_ray_intersection(intersection.position, newDirection);
        depth += intersection.depth;
    }

    if(intersection.hit){
        output.normal = intersection.normal;
        output.noisy_color = vec4<f32>(Hit(intersection, depth), 1);
    } else {
        output.noisy_color = NoHit(direction, start);
    }*/

    var ray_direction = normalize(direction + 0.01 * randomPoint(inputData.frame, direction));
    var intersection = get_ray_intersection(start, ray_direction);
    var tries = 0;

    output.noisy_color = Hit(intersection);

    while(intersection.hit || tries <= 2){
        tries ++;

        var scattered_direction = normalize(intersection.normal + randomPointInHemisphere(inputData.frame, intersection.normal, intersection.position));
        intersection = get_ray_intersection(intersection.position, scattered_direction);

        if(!intersection.hit){
            output.noisy_color = output.noisy_color + NoHit(scattered_direction, intersection.position);
        }

        output.noisy_color = output.noisy_color + Hit(intersection);
    }

    return output;
}

fn getTemporalData(
    pixel: vec2<u32>
) -> TemportalData {
    return temporalBuffer[pixel.x + pixel.y * u32(inputData.resolution.x)];
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

fn calculateTemporalData(
    pixel: vec2<u32>,
    traceOutput: Pixel,
    start: vec3<f32>,
    direction: vec3<f32>,
) -> TemportalData {
    var output: TemportalData;

    output.rayDirection = direction;

    return output;
}

fn calculatePixelColor(
    pixel: vec2<u32>
) -> TraceOutput {
    let direction = calculatePixelDirection(pixel);
    let start = inputData.CameraPosition;

    var output: TraceOutput;

    let temporalData = getTemporalData(pixel);
    var traceOutput = RunTracer(direction, start);

    traceOutput.velocity = (temporalData.rayDirection - direction).xy;

    output.pixel = traceOutput;
    output.temporalData = calculateTemporalData(pixel, traceOutput, start, direction);

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
const luma = vec4<f32>(0.299, 0.587, 0.114, 0);

fn applyFXAA(centerColor: vec4<f32>, fragCoord: vec2<i32>) -> vec4<f32> {
    let lumaCenter = dot(centerColor, luma);

    let lumaTop = dot(textureLoad(image_color_texture_read, fragCoord + vec2(0, -1), 0), luma);
    let lumaBottom = dot(textureLoad(image_color_texture_read, fragCoord + vec2(0, 1), 0), luma);
    let lumaLeft = dot(textureLoad(image_color_texture_read, fragCoord + vec2(-1, 0), 0), luma);
    let lumaRight = dot(textureLoad(image_color_texture_read, fragCoord + vec2(1, 0), 0), luma);

    let lumaMax = max(max(max(abs(lumaCenter - lumaTop), abs(lumaCenter - lumaBottom)),
                         abs(lumaCenter - lumaLeft)),
                     abs(lumaCenter - lumaRight));

    let blendFactor = clamp(1.0 / ((lumaMax * lumaMax) + 0.0001), 0.0, 1.0);

    return mix(centerColor, (
        textureLoad(image_color_texture_read, fragCoord + vec2(0, -1), 0) +
        textureLoad(image_color_texture_read, fragCoord + vec2(0, 1), 0) +
        textureLoad(image_color_texture_read, fragCoord + vec2(-1, 0), 0) +
        textureLoad(image_color_texture_read, fragCoord + vec2(1, 0), 0)
    ) * 0.25, blendFactor);
}

@fragment 
fn fragmentMain(fsInput: VertexOutput) -> @location(0) vec4f {
    // Indexing

    var pixelPosition = vec2<i32>(fsInput.position.xy);
    /*let halfWidth = round(inputData.resolution.x / 2);

    if(pixelPosition.x < halfWidth){
        pixelPosition.x += halfWidth;
    } else {
        pixelPosition.x -= halfWidth;
    }*/

    //let index = pixelToIndex(pixelPosition);
    var pixel = textureLoad(image_color_texture_read, pixelPosition, 0);
    //var pixel = imageBuffer[index].noisy_color;
    //var temporalData = temporalBuffer[index];

    if(inputData.antialias == 1){
        pixel = applyFXAA(pixel, pixelPosition);
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
    let pixelData = calculatePixelColor(global_invocation_id.xy);

    //imageBuffer[index] = pixelData.pixel;
    //temporalBuffer[index] = pixelData.temporalData;

    textureStore(image_color_texture, global_invocation_id.xy, pixelData.pixel.noisy_color);
}