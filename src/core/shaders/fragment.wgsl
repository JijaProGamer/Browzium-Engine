const luma = vec4<f32>(0.299, 0.587, 0.114, 0);

fn applyFXAA(centerColor: vec4<f32>, fragCoord: vec2<i32>) -> vec4<f32> {
    let lumaCenter = dot(centerColor, luma);

    let lumaTop = dot(textureLoad(image_color_texture_read, fragCoord + vec2(0, -1), 0), luma);
    let lumaBottom = dot(textureLoad(image_color_texture_read, fragCoord + vec2(0, 1), 0), luma);
    let lumaLeft = dot(textureLoad(image_color_texture_read, fragCoord + vec2(-1, 0), 0), luma);
    let lumaRight = dot(textureLoad(image_color_texture_read, fragCoord + vec2(1, 0), 0), luma);

    let lumaMax = max(max(max(abs(lumaCenter - lumaTop), abs(lumaCenter - lumaBottom)),
                         abs(lumaCenter - lumaLeft)),
                     abs(lumaCenter - lumaRight));

    let blendFactor = clamp(1.0 / ((lumaMax * lumaMax) + 0.0001), 0.0, 1.0);

    return mix(centerColor, (
        textureLoad(image_color_texture_read, fragCoord + vec2(0, -1), 0) +
        textureLoad(image_color_texture_read, fragCoord + vec2(0, 1), 0) +
        textureLoad(image_color_texture_read, fragCoord + vec2(-1, 0), 0) +
        textureLoad(image_color_texture_read, fragCoord + vec2(1, 0), 0)
    ) * 0.25, blendFactor);
}

@fragment 
fn fragmentMain(fsInput: VertexOutput) -> @location(0) vec4f {
    // Indexing

    var pixelPosition = vec2<i32>(fsInput.position.xy);
    /*let halfWidth = round(inputData.resolution.x / 2);

    if(pixelPosition.x < halfWidth){
        pixelPosition.x += halfWidth;
    } else {
        pixelPosition.x -= halfWidth;
    }*/

    //let index = pixelToIndex(pixelPosition);
    var pixel = textureLoad(image_color_texture_read, pixelPosition, 0);
    //var pixel = imageBuffer[index].noisy_color;
    //var temporalData = temporalBuffer[index];

    if(image_history_data.staticFrames == 0){
        textureStore(image_history, pixelPosition, vec4<f32>(0, 0, 0, 0));
    } else {
        let historyPixel = textureLoad(image_history_read, pixelPosition, 0);
        pixel = mix(historyPixel, pixel, clamp(1 / image_history_data.staticFrames, 0.05, 1));
        textureStore(image_history, pixelPosition, pixel);
    }

    /*if(inputData.antialias == 1){
        pixel = applyFXAA(pixel, pixelPosition);
    }*/

    if(inputData.gammacorrect == 1){
        let oldTransparency = pixel.w;
        pixel = pow(pixel, vec4<f32>(1.0 / 2.2));
        pixel.w = oldTransparency;
    }

    // Displaying

    //return vec4<f32>(position.xy / inputData.resolution, 0, 1);
    return pixel;
}