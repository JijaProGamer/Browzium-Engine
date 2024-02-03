// PCG Hash
// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
fn hash(input: u32) -> u32 {
    let state = input * 747796405u + 2891336453u;
    let word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

fn floatConstruct(m: u32) -> f32 {
    let ieeeMantissa: u32 = 0x007FFFFFu;
    let ieeeOne: u32 = 0x3F800000u; 

    var mBits: u32 = m & ieeeMantissa;
    mBits = mBits | ieeeOne;

    return bitcast<f32>(mBits) - 1;
}

fn random(seed: ptr<function,f32>) -> f32 {
    *seed = floatConstruct(hash(bitcast<u32>(*seed)));
    return *seed;
}

/*fn randomNormalDistribution(seed: f32) -> vec2<f32> {
    let seed1 = random(seed);
    let seed2 = random(seed1);

    let theta = 2 * 3.1415926 * seed1;
    let rho = sqrt(-2 * log(seed2));
    
    return vec2<f32>(rho * cos(theta), random(seed2));
}*/

fn randomFromVec2(seed: ptr<function,f32>, vec: vec2<f32>) -> f32 {
    *seed += dot(vec, vec2<f32>(43.321312, 2.421333341));
    random(seed);

    return *seed;
}

fn randomFromVec3(seed: ptr<function,f32>, vec: vec3<f32>) -> f32 {
    *seed += dot(vec, vec3<f32>(31.85175124, 32.2415625, -50.23123));
    random(seed);

    return *seed;
}

fn randomVec2FromVec2(seed: ptr<function,f32>, vec: vec2<f32>) -> vec2<f32> {
    randomFromVec2(seed, vec);

    var x = random(seed);
    var y = random(seed);

    return vec2<f32>((x - 0.5) * 2, (y - 0.5) * 2);
}

fn randomVec3FromVec3(seed: ptr<function,f32>, vec: vec3<f32>) -> vec3<f32> {
    randomFromVec3(seed, vec);

    var x = random(seed);
    var y = random(seed);
    var z = random(seed);

    return vec3<f32>((x - 0.5) * 2, (y - 0.5) * 2, (z - 0.5) * 2);
}

fn randomPoint(seed: ptr<function,f32>, position: vec3<f32>) -> vec3<f32> {
    return normalize(randomVec3FromVec3(seed, position));
}

fn randomPoint2(seed: ptr<function,f32>, position: vec2<f32>) -> vec2<f32> {
    return normalize(randomVec2FromVec2(seed, position));
}

fn randomPointOnCircle(seed: ptr<function,f32>, position: vec2<f32>) -> vec2<f32> {
    var tries = 0;
    var output = randomVec2FromVec2(seed, position);

    while(dot(output, output) > 1 && tries < 10){
        output = randomVec2FromVec2(seed, position);
        tries ++;
    }

    return normalize(output);
}

fn randomPointOnSphere(seed: ptr<function,f32>, position: vec3<f32>) -> vec3<f32> {
    var tries = 0;
    var output = randomVec3FromVec3(seed, position);

    while(dot(output, output) > 1 && tries < 10){
        output = randomVec3FromVec3(seed, position);
        tries ++;
    }

    return normalize(output);
}

/*fn randomPointInCircle(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var output: Random3Vec3Output;

    let x = randomNormalDistribution(seed);
    let y = randomNormalDistribution(x.y);
    let z = randomNormalDistribution(y.y);

    output.output = normalize(vec3<f32>(x.x, y.x, z.x));
    output.seed = z.y;

    return output;
}*/

/*fn randomPointInCircle(seed: f32, position: vec3<f32>) -> Random3Vec3Output {
    var output: Random3Vec3Output;

    let newSeed = randomVec3(seed, position);
    let u1 = random(newSeed);
    let u2 = random(u1);

    let phi = acos(2.0 * u1 - 1.0) - 3.14159265359 / 2.0;
    let lambda = 2.0 * 3.14159265359 * u2;

    let x = cos(phi) * cos(lambda);
    let y = cos(phi) * sin(lambda);
    let z = sin(phi);

    output.output = vec3<f32>(x, y, z);
    output.seed = u2;

    return output;
}*/