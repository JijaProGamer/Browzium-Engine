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


const maxDepth: i32 = 8;

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
        let emittance = material.color * material.emittance;

        if(depth == 0){
            if (!intersection.hit) { intersection.depth = 999999; intersection.normal = -realDirection; material.color = NoHit(realDirection, realStart); }

            output.normal = intersection.normal;
            output.depth = intersection.depth;
            output.albedo = material.color;
        }

        if (!intersection.hit) {
            hit_light = true;
            accumulatedColor *= NoHit(realDirection, realStart);
            break;
        }

        let newDirection = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
        pixelHash = newDirection.seed;

        let p = 1.0 / (2.0 * 3.141592653589);
        let cos_theta = dot(newDirection.output, intersection.normal);
        
        let BRDF = (max(1 - material.emittance, 0) * material.color) / 3.141592653589;

        accumulatedColor *= emittance + (BRDF * cos_theta / p);

        if(material.emittance > 0){
            hit_light = true;
            break;
        }

        realStart = intersection.position;
        realDirection = newDirection.output;
    }

    //if(true){
    if(hit_light){
        output.noisy_color = vec4<f32>(accumulatedColor, 1);
    }

    return output;
}

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    var realDirection = direction;
    var realStart = start;
    var accumulatedColor: vec3<f32> = vec3<f32>(0.0);
    var pixelHash = rawPixelHash;
    var hit_light = false;
    var depth: i32 = 0;

    for (; depth <= maxDepth; depth = depth + 1) {
        if (depth >= maxDepth) {
            break;
        }

        var intersection = get_ray_intersection(realStart, realDirection);

        if (!intersection.hit) {
            hit_light = true;
            accumulatedColor = NoHit(realDirection, realStart);
            break;
        }

        let material = intersection.material;
        let emittance = material.color * material.emittance;

        let newDirection = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
        pixelHash = newDirection.seed;

        let p = 1.0 / (2.0 * 3.141592653589);
        let cos_theta = dot(newDirection.output, intersection.normal);
        let BRDF = ((1 - material.emittance) * material.color) / 3.141592653589;

        accumulatedColor = accumulatedColor + emittance + (BRDF * accumulatedColor * cos_theta / p);

        if(material.emittance > 0){
            hit_light = true;
            break;
        }

        realStart = intersection.position;
        realDirection = newDirection.output;
        depth = depth + 1;
    }

    if(hit_light){
        output.noisy_color = vec4<f32>(accumulatedColor / f32(depth), 1);
    }

    //output.noisy_color = vec4<f32>(randomVec2(pixelHash, pixel), randomVec2(pixelHash, pixel), randomVec2(pixelHash, pixel), 1);

    return output;
}*/

/*fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
    var output: Pixel;

    var pixelHash = rawPixelHash;
    var intersection = get_ray_intersection(start, direction);
    var accumulated_radiance: vec3<f32>;

    if (intersection.hit) {
        let BRDF1 = dot(direction, intersection.normal);
        accumulated_radiance = intersection.material.color * BRDF1 + intersection.material.color * intersection.material.emittance;

        var tries = 1;
        var hit_light = false;

        while (tries < maxDepth) {
            if(intersection.material.emittance > 0){
                accumulated_radiance += intersection.material.color * intersection.material.emittance;
                hit_light = true;
                break;
            }

            var direction_modifier = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
            pixelHash = direction_modifier.seed;
            var scattered_direction = direction_modifier.output;

            var new_intersection = get_ray_intersection(intersection.position, scattered_direction);

            if (!new_intersection.hit) {
                accumulated_radiance += NoHit(scattered_direction, intersection.position).xyz;
                hit_light = true;
                break;
            } else {
                let BRDF = dot(scattered_direction, new_intersection.normal);
                let incoming_light = intersection.material.color;

                accumulated_radiance += BRDF * incoming_light;
            }

            intersection = new_intersection;
            tries++;
        }


        //if(true){
        if(hit_light){
            //output.noisy_color = vec4<f32>(accumulated_radiance, 1);
            output.noisy_color = vec4<f32>(accumulated_radiance / f32(tries), 1);
        } else {
            output.noisy_color = vec4<f32>(0, 0, 0, 1);
        }
    } else {
        output.noisy_color = vec4<f32>(NoHit(direction, start), 1);
    }

    return output;
}*/

/*
fn RunTracer(direction: vec3<f32>, start: vec3<f32>, pixel: vec2<f32>, rawPixelHash: f32) -> Pixel {
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

    var intersection = get_ray_intersection(start, direction);
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
    }

    return output;
}

*/