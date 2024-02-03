#include "intersection_test.wgsl"
#include "classes/random.wgsl"

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