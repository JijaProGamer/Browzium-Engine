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

    if(t < 0.01){
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