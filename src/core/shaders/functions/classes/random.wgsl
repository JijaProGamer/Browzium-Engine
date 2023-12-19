fn hash(input: u32) -> u32 {
    var x = input;

    x += (x << 10u);
    x ^= ( x >>  6u ) * x;
    x += ( x <<  3u );
    x ^= ( x >> 11u ) * x * x;
    x += ( x << 15u );
    
    return x;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    return bitcast<f32>(mBits) - 1;
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
    return floatConstruct(hash(bitcast<u32>(seed)));
}

fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    return random(seed + vec.x * 0.44 - vec.y);
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> Random3Vec2Output {
    var output: Random3Vec2Output;
    var seedValue = randomVec2(seed, vec);

    var outputVector = vec2<f32>(random(vec.x * seedValue), random(vec.x * seedValue)); // tap tap ingerasi
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