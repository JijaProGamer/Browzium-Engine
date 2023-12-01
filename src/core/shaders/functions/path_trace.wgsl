#include "intersection_test.wgsl"
#include "classes/random.wgsl"

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

    var pixelHash = rawPixelHash;
    var intersection = get_ray_intersection(start, direction);
    var lastDirection = direction;
    var tries = 1;

    if(intersection.hit){
        //output.noisy_color = Hit(intersection);
        //output.noisy_color = vec4<f32>(randomPointInHemisphere(randomVec2(inputData.frame * 3.141592, vec2<f32>(pixel)) , intersection.normal, intersection.position), 1);

        while(tries <= 15){
            //let reflectedDirection = lastDirection - 2.0 * dot(lastDirection, intersection.normal) * intersection.normal;

            var direction_modifier = randomPointInHemisphere(pixelHash, intersection.normal, intersection.position);
            pixelHash = direction_modifier.seed;

            var scattered_direction = direction_modifier.output;
            //var scattered_direction = normalize(reflectedDirection * intersection.material.reflectance + direction_modifier.output * (1 - intersection.material.reflectance));
            lastDirection = scattered_direction;
            intersection = get_ray_intersection(intersection.position, scattered_direction);

            if(!intersection.hit){
                output.noisy_color = output.noisy_color + NoHit(scattered_direction, intersection.position);
                break;
            }

            output.noisy_color = output.noisy_color + Hit(intersection);
            tries ++;
        }

        output.noisy_color /= f32(tries);
    } else {
        output.noisy_color = NoHit(direction, start);
    }

    return output;
}