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

const errorAmount = 0.0001;

fn hit_triangle(tri: Triangle, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> HitResult {
    var result: HitResult;

    if(!is_triangle_facing_camera(tri, ray_direction)){
        return result;
    }

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
    //result.texture = w * tri.textureA + u * tri.textureB + v * tri.textureC;
    result.uv = w * vec2<f32>(0, 0) + u * vec2<f32>(0, 1) + v * vec2<f32>(1, 0);

    /*if(!is_triangle_facing_camera(tri, ray_direction)){
        result.normal = -result.normal;
    }*/

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