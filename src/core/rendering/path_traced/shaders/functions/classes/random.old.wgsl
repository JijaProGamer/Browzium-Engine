/*fn hash(x: u32) -> u32 {
    var output: u32 = x;

    output = output + (output << 10u);
    output = output ^ (output >> 6u);
    output = output + (output << 3u);
    output = output ^ (output >> 11u);
    output = output + (output << 15u);
    
    return output;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    let f: f32 = bitcast<f32>(mBits);
    return f - 1.0;
}*/

struct Random3Vec3Output {
    output: vec3<f32>,
    seed: f32
};

struct Random3Vec2Output {
    output: vec2<f32>,
    seed: f32
};

fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    var vector = vec3<f32>(seed, vec);

    vector = fract(vector * 0.14319031);
    vector += dot(vector, vector.zyx + 3.3252653);
    return fract((vector.x + vector.y) * vector.z) - 0.5;
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> Random3Vec2Output {
    var vector = vec3<f32>(seed, vec);
    var output: Random3Vec2Output;

    vector = fract(vector * vec3<f32>(0.1031, 0.1030, 0.0973));
    vector += dot(vector, vector.yzx + 33.33);
    var outputVector = fract((vector.xx + vector.yz) * vector.zy) - vec2<f32>(0.5);

    output.seed = outputVector.y + outputVector.x / .43145 + seed * 2.634145;
    output.output = outputVector;

    return output;
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> Random3Vec3Output {
    var vector = vec4<f32>(seed, vec);
    var output: Random3Vec3Output;

    vector = fract(vector * vec4<f32>(.9898, 78.233, 43.094, 94.457));
    vector += dot(vector, vector.wzxy + 33.33);
    vector = fract((vector.xxyz + vector.yzzw) * vector.zywx) - vec4<f32>(0.5);

    output.seed = vector.y * seed * .65376464 + vector.x - vector.z * vector.w;
    output.output = vector.wxz;

    return output;
}

fn randomPoint(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var output = random3Vec3(seed, position);
    output.output = normalize(output.output);
    return output;
}

fn randomPoint2(seed: f32, position: vec2<f32>) -> Random3Vec2Output {
    var output = random2Vec2(seed, position);
    output.output = normalize(output.output);
    return output;
}

fn randomPointInHemisphere(seed: f32, normal: vec3<f32>, position: vec3<f32>) -> Random3Vec3Output {
    var randomVec: Random3Vec3Output;
    var randomiser: f32 = seed;
    var tries: i32 = 0;

    while (true) {
        randomVec = randomPoint(randomiser, position);
        randomiser = randomVec.seed;
        tries += 1;

        if (length(randomVec.output) <= 1.0 || tries > 10) {
            randomVec.output = normalize(randomVec.output);
            randomVec.seed = randomiser;
            break;
        }
    }

    if (dot(randomVec.output, normal) < 0.0) {
        randomVec.output = -randomVec.output;
    }

    return randomVec;
}
