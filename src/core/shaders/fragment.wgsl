const ACES_a = 2.51;
const ACES_b = 0.03;
const ACES_c = 2.43;
const ACES_d = 0.59;
const ACES_e = 0.14;

fn applyACES(x: vec3<f32>) -> vec3<f32> {
    return clamp((x * (ACES_a * x + ACES_b)) / (x * (ACES_c * x + ACES_d) + ACES_e), vec3<f32>(0.0), vec3<f32>(1.0));
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
    //var pixel = textureLoad(image_albedo_texture_read, pixelPosition, 0);

    //var pixel = imageBuffer[index].noisy_color;
    //var temporalData = temporalBuffer[index];

    /*if(image_history_data.staticFrames == 0){
        textureStore(image_history, pixelPosition, vec4<f32>(0, 0, 0, 0));
    } else {
        let historyPixel = textureLoad(image_history_read, pixelPosition, 0);

        //pixel = (pixel + historyPixel) / 2;
        pixel = mix(historyPixel, pixel, clamp(1 / image_history_data.staticFrames, 0.01, 1));
        //pixel = mix(historyPixel, pixel, 1 / image_history_data.staticFrames);
        textureStore(image_history, pixelPosition, pixel);
    }*/

    if(image_history_data.staticFrames == 0){
        textureStore(image_history, pixelPosition, vec4<f32>(0, 0, 0, 0));
    } else {
        let w = pixel.w;

        let historyPixel = textureLoad(image_history_read, pixelPosition, 0);
        pixel = mix(historyPixel, pixel, clamp(1 / image_history_data.staticFrames, 0.025, 1)); 

        if(w > 0){
            textureStore(image_history, pixelPosition, pixel);
        }

        pixel.w = 1;
    }

    if(inputData.tonemapmode == 1){
        pixel = vec4<f32>(applyACES(pixel.xyz), pixel.w);
    }

    if(inputData.gammacorrect == 1){
        let oldTransparency = pixel.w;
        pixel = pow(pixel, vec4<f32>(1.0 / 2.2));
        pixel.w = oldTransparency;
    }

    // Displaying

    //return vec4<f32>(position.xy / inputData.resolution, 0, 1);
    return pixel;
}