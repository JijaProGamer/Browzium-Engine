fn hit_triangle(tri: Triangle, ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> f32 {
    /*if(!is_triangle_facing_camera(tri, ray_direction)){
        return -1;
    }*/

    let edge1 = tri.b - tri.a;
    let edge2 = tri.c - tri.a;
    let h = cross(ray_direction, edge2);
    let a = dot(edge1, h);

    if a > -0.00001 && a < 0.00001 {
        return -1;
    }

    let f = 1.0 / a;
    let s = ray_origin - tri.a;
    let u = f * dot(s, h);

    if u < 0.0 || u > 1.0 {
        return -1;
    }

    let q = cross(s, edge1);
    let v = f * dot(ray_direction, q);

    if v < 0.0 || u + v > 1.0 {
        return -1;
    }

    let t = f * dot(edge2, q);

    if(t < 1e-6){
        return -1;
    }

    return t;
}

fn is_triangle_facing_camera(tri: Triangle, ray_direction: vec3<f32>) -> bool {
    let dotProductA = dot(tri.na, ray_direction);
    let dotProductB = dot(tri.nb, ray_direction);
    let dotProductC = dot(tri.nc, ray_direction);
    
    return dotProductA < 0.0 && dotProductB < 0.0 && dotProductC < 0.0;
}