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


const maxDepth: i32 = 5;

struct BRDFDirectionOutput {
    isSpecular: bool,
    direction: vec3<f32>,
    outputHash: f32,
}

fn BRDFDirection(
    intersection: HitResult,
    oldDirection: vec3<f32>,
    rawHash: f32,
) -> BRDFDirectionOutput { 
    var output: BRDFDirectionOutput;
    var pixelHash = rawHash;
    let doSpecular = intersection.material.reflectance;
    
    var diffuseDirectionValue = randomPointInCircle(pixelHash, intersection.position);
    pixelHash = diffuseDirectionValue.seed;

    let reflectedDir = (oldDirection - 2.0 * dot(oldDirection, intersection.normal) * intersection.normal);
    let diffuseDirection = normalize(intersection.normal + diffuseDirectionValue.output);
    let specularDir = normalize(mix(reflectedDir, diffuseDirection, 0/*intersection.material.roughness*/));
    let outputDir = mix(diffuseDirection, specularDir, f32(doSpecular));

    output.isSpecular = doSpecular;
    output.direction = outputDir;
    output.outputHash = pixelHash;

    return output;
}

fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    var intersection: HitResult;
    var realDirection = direction;
    var realStart = start;

    var rayColour = vec3<f32>(1);

    var pixelHash = rawPixelHash;
    var hit_light = false;
    var depth: i32 = 0;

    var gatherDenoisingData = true;

    var emittance: vec3<f32>;

    for (; depth <= maxDepth; depth = depth + 1) {
        if (depth >= maxDepth || (!intersection.hit && depth > 0)) {
            break;
        }

        intersection = get_ray_intersection(realStart, realDirection);
        var material = intersection.material;
        emittance = material.color * material.emittance;

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
            output.albedo = material.color;
            gatherDenoisingData = false;
        }

        if (!intersection.hit) {
            emittance = NoHit(realDirection, realStart);

            output.noisy_color += vec4<f32>(rayColour * emittance, 0);
            break;
        }

        let BRDFDirectionValue = BRDFDirection(intersection, realDirection, pixelHash);
        let newDirection = BRDFDirectionValue.direction;
        let diffuse = (max(1 - material.emittance, 0) * material.color);
        pixelHash = BRDFDirectionValue.outputHash;

        /*if(isSpecular <= material.reflectance){
            var newDirectionValue = randomPointInCircle(pixelHash, intersection.position);
            if(dot(newDirectionValue.output, intersection.normal) > 0){
                newDirectionValue.output = -newDirectionValue.output;
            }

            let reflected = (realDirection - 2.0 * dot(realDirection, intersection.normal) * intersection.normal);
            newDirection = normalize((1 - material.reflectance) *  newDirectionValue.output + material.reflectance * reflected);
            pixelHash = newDirectionValue.seed;

            diffuse = (max(1 - material.emittance, 0) * material.color);
        } else {
            var newDirectionValue = randomPointInCircle(pixelHash, intersection.position);
            newDirectionValue.output = normalize(intersection.normal + newDirectionValue.output);
            newDirection = newDirectionValue.output;
            pixelHash = newDirectionValue.seed;

            let p = 1.0 / (2.0 * 3.141592653589);
            let cos_theta = dot(newDirection, intersection.normal);
            
            var BRDF = (max(1 - material.emittance, 0) * material.color) / 3.141592653589;
            diffuse = BRDF * cos_theta / p;
        }*/

        if(depth == 0) {
            if(material.reflectance >= 0.35){
            //if(dot(reflected, newDirectionValue.output) > 0.9){
                gatherDenoisingData = true;
            }
        }

        output.noisy_color += vec4<f32>(rayColour * emittance, 0);
        rayColour *= emittance + diffuse;


        realStart = intersection.position;
        realDirection = newDirection;
    }

    output.noisy_color.w = length(output.noisy_color.xyz / emittance);
    if(emittance.x + emittance.y + emittance.z == 0){
        output.noisy_color.w = 0;
    }

    return output;
}

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    if (!hit_octree(start, direction, inputTreeParts[0])) {
        output.noisy_color = vec4<f32>(1);
        output.albedo = NoHit(direction, start);
    } else {
        output.noisy_color = vec4<f32>(1);
        for(var i = 1; i < 7; i++){
            if(hit_octree(start, direction, inputTreeParts[i])){
                output.albedo = vec3<f32>(f32(i - 1) / 6, 1, 0);
            }
        }
    }

    return output;
}*/

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    output.noisy_color = vec4<f32>(1);

    var random = random3Vec3(rawPixelHash, vec3<f32>(pixel, 50));
    output.albedo = vec3<f32>((random.output.x + 1) / 2, (random.output.y + 1) / 2, (random.output.z + 1) / 2);

    return output;
}*/