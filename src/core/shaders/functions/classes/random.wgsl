fn randomVec2(seed: f32, vec: vec2<f32>) -> f32 {
    var vector = vec3<f32>(seed, vec);

    vector  = fract(vector * .1031);
    vector += dot(vector, vector.zyx + 31.32);
    return fract((vector.x + vector.y) * vector.z);
}

struct random3Vec3Output {
    output: vec3<f32>,
    seed: f32
}

struct random3Vec2Output {
    output: vec2<f32>,
    seed: f32
}

fn random2Vec2(seed: f32, vec: vec2<f32>) -> random3Vec2Output {
    var vector = vec3<f32>(seed, vec);
    var output: random3Vec2Output;

	vector = fract(vector * vec3(.1031, .1030, .0973));
    vector += dot(vector, vector.yzx+33.33);
    var outputVector = fract((vector.xx+vector.yz)*vector.zy);

    output.seed = pow(outputVector.y * outputVector.x / .43145 * seed, .141592);
    output.output = outputVector;

    return output;
}

fn random3Vec3(seed: f32, vec: vec3<f32>) -> random3Vec3Output {
    var vector = vec4<f32>(seed, vec);
    var output: random3Vec3Output;

	vector = fract(vector  * vec4(.1031, .1030, 0.0973, .1099));
    vector += dot(vector, vector.wzxy+33.33);
    vector = fract((vector.xxyz+vector.yzzw)*vector.zywx);

    output.seed = pow(vector.y * seed, .141592);
    output.output = vector.wxz;

    return output;
}

fn randomPoint(seed: f32, position: vec3<f32>) -> random3Vec3Output{
    var output = random3Vec3(seed, position);
    output.output = normalize(output.output);

    return output;
}

fn randomPoint2(seed: f32, position: vec2<f32>) -> random3Vec2Output{
    var output = random2Vec2(seed, position);
    output.output = normalize(output.output);

    return output;
}

fn randomPointInHemisphere(seed: f32, normal: vec3<f32>, position: vec3<f32>) -> random3Vec3Output {
    /*var randomVec: vec3<f32>;
    var randomiser: f32 = 1;

    while(true){
        randomVec = random3Vec3(seed * randomiser, position);
        randomiser *= 3.141592;

        if(length(randomVec) < 1){
            randomVec = normalize(randomVec);
            break;
        }
    }*/

    var randomVec = randomPoint(seed, position);

    if(dot(randomVec.output, normal) < 0){
        randomVec.output = -randomVec.output;
    }

    return randomVec;
}