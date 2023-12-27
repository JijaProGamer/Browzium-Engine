#include "intersection_test.wgsl"
#include "classes/random.wgsl"

fn NoHit(
    direction: vec3<f32>, 
    start: vec3<f32>
) -> vec3<f32> {
    let a = 0.5 * (direction.y + 1.0);

    let White = vec3<f32>(0.8, 0.8, 0.8);
    let Blue = vec3<f32>(0.15, 0.3, 0.9);

    return (0.6-a) * White + (a + 0.4) * Blue;
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

/*fn CalculateDirect(
    rayPosition: vec3<f32>,
    rawPixelHash: f32,
) -> DirectCalculationOutput {
    var output: DirectCalculationOutput;

    var pixelHash = rawPixelHash;
    let triIndex = u32(floor(pixelHash * inputLightMap.triangle_count));
    let tri = inputMap.triangles[u32(inputLightMap.triangles[triIndex])];

    let lightSample = RandomPointOnTriangle(tri, pixelHash);
    let lightPosition = lightSample.xyz;

    let shadowRayDirection = normalize(lightPosition - rayPosition);
    let shadowIntersection = get_ray_intersection(rayPosition, shadowRayDirection);

    if (shadowIntersection.hit && shadowIntersection.object_id == tri.object_id) {
        let material = inputMaterials[i32(tri.material_index)];

        //let P = -dot(shadowRayDirection, shadowIntersection.normal) / dot(lightPosition - rayPosition, lightPosition - rayPosition);
        //output.color = material.emittance * material.color * P * (dot(shadowRayDirection, shadowIntersection.normal) / 3.141592);

        let cos_theta = dot(-shadowRayDirection, shadowIntersection.normal);
        let brdf = (material.emittance * material.color) / 3.141592;
        let color = brdf * cos_theta / (1 / (2 * 3.141592));

        output.color =  color;
        output.hit = shadowIntersection;
    }

    output.seed = lightSample.w;
    output.direction = shadowRayDirection;

    return output;
}*/

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
    //let lightSample = vec4<f32>((tri.a + tri.b + tri.c) / 3, pixelHash);

    let lightPosition = lightSample.xyz;

    let shadowRayDirection = normalize(lightPosition - rayPosition);
    //let shadowIntersection = get_light_ray_intersection(rayPosition, shadowRayDirection, tri.object_id);
    let shadowIntersection = get_ray_intersection(rayPosition, shadowRayDirection);

    if (shadowIntersection.hit && shadowIntersection.object_id == tri.object_id) {
        let material = inputMaterials[i32(tri.material_index)];

        let cos_theta = dot(-shadowRayDirection, shadowIntersection.normal);
        let brdf = getColor(material, shadowIntersection).rgb / 3.141592;
        let color = brdf * cos_theta /  (1 / (2 * 3.141592));
        output.color = color;

        output.hit = shadowIntersection;
        output.wasHit = true;
    }

    output.seed = lightSample.w;
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

const maxDepth: i32 = 4;

fn RunTracer(direction: vec3<f32>, start: vec3<f32>, rawPixelHash: f32) -> Pixel {
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
        var reflected = (max(1 - material.emittance, 0) * getColor(material, intersection).rgb);
        pixelHash = BRDFDirectionValue.outputHash;

        //var directIncoming = CalculateDirect(intersection.position, pixelHash);
        var indirectIncoming = getColor(material, intersection).rgb * material.emittance;
        //var weightIncoming = 1.0; 
        //if(depth == 1) {weightIncoming = 0.5;}

        emittance = indirectIncoming;

        //emittance =  indirectIncoming + directIncoming.color;
        //emittance = directIncoming.color;
        //pixelHash = directIncoming.seed;

        gatherDenoisingData = depth == 0 && (BRDFDirectionValue.isSpecular || BRDFDirectionValue.isTransparent);
        wasReflection = gatherDenoisingData;

        incomingLight += emittance * rayColor;

        if(!gatherDenoisingData){
            rayColor *= reflected;
        }

        realStart = intersection.position;
        realDirection = BRDFDirectionValue.direction;
        oldMaterial = material;
    }

    output.noisy_color = vec4<f32>(rayColor + incomingLight, 0);
    
    output.seed = pixelHash;
    return output;
}

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

    var directIncoming = CalculateDirect(intersection.position, rawPixelHash);

    if(directIncoming.wasHit){
        output.albedo = getColor(material, intersection).rgb * directIncoming.color; // dot(direction, directIncoming.direction);
    }

    if(material.emittance > 0){
        output.albedo = getColor(material, intersection).rgb * material.emittance;
    }

    output.seed = directIncoming.seed;

    return output;
}*/

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
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