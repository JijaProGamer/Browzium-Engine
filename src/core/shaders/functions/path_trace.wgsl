#include "intersection_test.wgsl"
#include "classes/random.wgsl"

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

    var applyRotation = false;
    var fistColor = vec3<f32>(1);

    for (; depth <= maxDepth; depth = depth + 1) {
        if (depth >= maxDepth) {
            break;
        }

        var intersection = get_ray_intersection(realStart, realDirection);
        var material = intersection.material;
        var emittance = material.color * material.emittance;

        if(depth == 0 || applyRotation == true){
            if (!intersection.hit) { 
                intersection.depth = 999999; 
                intersection.normal = -realDirection; 
                output.intersection = 99999.0 * realDirection;
                material.color = NoHit(realDirection, realStart);
                output.object_id = -1;
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

        let newDirectionValue = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
        let reflected = (realDirection - 2.0 * dot(realDirection, intersection.normal) * intersection.normal);
        let newDirection = normalize((1 - material.reflectance) *  newDirectionValue.output + material.reflectance * reflected);

        pixelHash = newDirectionValue.seed;

        let p = 1.0 / (2.0 * 3.141592653589);
        let cos_theta = dot(newDirection, intersection.normal);
        
        var BRDF = (max(1 - material.emittance, 0) * material.color) / 3.141592653589;
        var diffuse = BRDF * cos_theta / p;

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