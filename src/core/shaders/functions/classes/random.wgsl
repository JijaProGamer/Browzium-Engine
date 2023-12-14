fn hash(input: u32) -> u32 {
    var x = input;

    x ^= x >> 17;
    x *= 0xed5ad4bb;
    x ^= x >> 11;
    x *= 0xac4c1b51;
    x ^= x >> 15;
    x *= 0x31848bab;
    x ^= x >> 14;
    
    return x;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    let f: f32 = bitcast<f32>(mBits);
    return f - 1.0;
}

fn inverseFloatConstruct(f: f32) -> u32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u;

    let fBits: u32 = bitcast<u32>(f);
    let mBits: u32 = fBits & ieeeMantissa;

    let mantissaWithImplicitBit: u32 = mBits | ieeeOne;
    return mantissaWithImplicitBit;
}

struct Random3Vec3Output {
    output: vec3<f32>,
    seed: f32
};

struct Random3Vec2Output {
    output: vec2<f32>,
    seed: f32
};

fn random(seed: f32) -> f32 {
    return floatConstruct(hash(inverseFloatConstruct(seed)));
}

fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    var vector = vec3<f32>(seed, vec);

    vector = fract(vector * 0.75318531);
    vector += dot(vector, vector.zyx + .4143);

    return random(vector.x + vector.y + vector.z);
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> Random3Vec2Output {
    var vector = vec3<f32>(seed, vec);
    var output: Random3Vec2Output;

    vector = fract(vector * vec3<f32>(0.1031, 0.1030, 0.0973));
    vector += dot(vector, vector.yzx + 33.33);

    var outputVector = fract((vector.xx + vector.yz) * vector.zy) - vec2<f32>(0.5);

    outputVector = vec2<f32>(random(outputVector.x), random(outputVector.y)); // tap tap ingerasi

    output.seed = outputVector.y + outputVector.x / .43145 + seed * 2.634145;
    output.output = outputVector;
    
    return output;
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> Random3Vec3Output {
    var vector = vec4<f32>(seed, vec);
    var output: Random3Vec3Output;

    vector = fract(vector * vec4<f32>(.9898, 78.233, 43.094, 94.457));
    vector += dot(vector, vector.wzxy + 33.33);

    vector = vec4<f32>(random(vector.x), random(vector.y), random(vector.z), random(vector.w)); // tap tap ingerasi
    vector = fract((vector.xxyz + vector.yzzw) * vector.zywx);

    vector -= vec4<f32>(0.5);

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
    randomVec.seed = seed;

    var r1: f32 = random(seed);
    var r2: f32 = random(r1 * seed * random(position.x / position.y + position.z * 33.33));

    var phi: f32 = 2.0 * 3.141592653589793 * r1;
    var cosTheta: f32 = sqrt(1.0 - r2);
    var sinTheta: f32 = sqrt(r2);

    var x: f32 = cos(phi) * sinTheta;
    var y: f32 = cosTheta;
    var z: f32 = sin(phi) * sinTheta;

    //var hemisphereSample: vec3<f32> = normalize(vec3<f32>(x - 0.5, y - 0.5, z - 0.5));
    var hemisphereSample: vec3<f32> = normalize(vec3<f32>(x, y, z));

    if (dot(hemisphereSample, normal) >= 0.0) {
        randomVec.output = hemisphereSample;
    } else {
        randomVec.output = -hemisphereSample;
    }

    return randomVec;
}