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

    vector = vector * 0.75318531;
    vector += dot(vector, vector.zyx + .4143);

    return random(vector.x + vector.y + vector.z);
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> Random3Vec2Output {
    var vector = vec3<f32>(seed, vec);
    var output: Random3Vec2Output;

    vector = vector * vec3<f32>(0.1031, 0.1030, 0.0973);
    vector += dot(vector, vector.yzx + 33.33);

    var outputVector = (vector.xx + vector.yz) * vector.zy;

    outputVector = vec2<f32>(random(outputVector.x), random(outputVector.y)); // tap tap ingerasi
    outputVector -= vec2<f32>(0.5);
    outputVector *= 2;

    output.seed = random(outputVector.y + outputVector.x / .43145 + seed * 2.634145);
    output.output = outputVector;
    
    return output;
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> Random3Vec3Output {
    var vector = vec4<f32>(seed, vec);
    var output: Random3Vec3Output;

    vector = vector * vec4<f32>(.9898, 78.233, 43.094, 94.457);
    vector += dot(vector, vector.wzxy + 33.33);

    vector = (vector.xxyz + vector.yzzw) * vector.zywx;
    vector = vec4<f32>(random(vector.x), random(vector.y), random(vector.z), random(vector.w)); // tap tap ingerasi
    vector -= vec4<f32>(0.5);
    vector *= 2;

    output.seed = random(vector.y + seed * .65376464 + vector.x - vector.z * vector.w);
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

fn randomPointInCircle(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var outputSeed = seed;

    var tries = 0;
    var output = random3Vec3(outputSeed, position);
    outputSeed = output.seed;
    while(dot(output.output, output.output) > 1 && tries < 10){
        outputSeed = output.seed;
        output = random3Vec3(outputSeed, position);
        tries ++;
    }

    output.output = normalize(output.output);
    output.seed = outputSeed;

    return output;
}