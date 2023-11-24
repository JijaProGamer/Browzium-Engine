#include "intersection_test.wgsl"

fn RunTracer(direction: vec3<f32>, start: vec3<f32>) -> Pixel {
    var output: Pixel;

    /*output.noisy_color.r = direction.x;
    output.noisy_color.g = direction.y;
    output.noisy_color.b = direction.z;
        
    return output;*/

    var hit: bool = false;
    var depth: f32 = 999999;
    var material: Material;

    for (var i: f32 = 0; i < inputMap.triangle_count; i = i + 1) {
        let currentTriangle = inputMap.triangles[u32(i)];
        let hit_depth = hit_triangle(currentTriangle, start, direction);

        if (hit_depth > 0 && hit_depth < depth) {
            material = inputMaterials.materials[u32(currentTriangle.material_index)];
            depth = hit_depth;
            hit = true;
        }
    }

    if(hit){
        let distance = min(0.35, depth / 25);
        //var distance: f32 = 0;

        output.noisy_color.r = material.color.x - distance;
        output.noisy_color.g = material.color.y - distance;
        output.noisy_color.b = material.color.z - distance;

        /*output.noisy_color.r = 1 - (depth / 5);
        output.noisy_color.g = 1 - (depth / 10);
        output.noisy_color.b = 0;*/
    }

    return output;
}