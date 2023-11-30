fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    var vector = vec3<f32>(seed, vec);

    vector  = fract(vector * .1031);
    vector += dot(vector, vector.zyx + 31.32);
    return fract((vector.x + vector.y) * vector.z);
}

fn randomVec3(seed: f32, vec: vec3<f32>) -> f32 {
    var vector = vec4<f32>(seed, vec);

    vector = fract(vector * .1031);
    vector += dot(vector, vector.wzyx + 31.32);
    return fract((vector.x + vector.y) * vector.z * vector.w);
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> vec3<f32> {
    var vector = vec4<f32>(seed, vec);

    vector = fract(vector * vec4(.1031, .1030, 0.0973, .1099));
    vector += dot(vector, vector.wzxy+33.33);
    vector = fract((vector.xxyz+vector.yzzw)*vector.zywx);

    return vector.wxz * vector.y;
}

fn randomPoint(seed: f32, position: vec3<f32>) -> vec3<f32>{
    return normalize(random3Vec3(seed, position));
}

fn randomPointInHemisphere(seed: f32, normal: vec3<f32>, position: vec3<f32>) -> vec3<f32> {
    var randomVec = normalize(random3Vec3(seed, position));

    if(dot(randomVec, normal) < 0){
        return -randomVec;
    }

    return randomVec;
}