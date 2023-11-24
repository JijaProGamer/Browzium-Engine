import * as tf from '@tensorflow/tfjs';
import '@tensorflow/tfjs-backend-webgpu';

tf.setBackend('webgpu')

function makeGeneratorCore(forTraining=false) {
    const model = tf.sequential();

    // Encoder

    model.add(tf.layers.conv2d({
        filters: 32,
        kernelSize: 8,
        strides: 1,
        activation: 'relu',
        inputShape: [null, null, 3],
        padding: 'same',
        kernelInitializer: 'randomNormal'
    }));

    model.add(tf.layers.maxPooling2d({ poolSize: [2, 2], strides: [2, 2] }));

    model.add(tf.layers.conv2d({
        filters: 64,
        kernelSize: 4,
        strides: 2,
        activation: 'relu',
        padding: 'same',
        kernelInitializer: 'randomNormal'
    }));

    // Decoder

    model.add(tf.layers.upSampling2d({ size: [2, 2] }));

    model.add(tf.layers.conv2dTranspose({
        filters: 64,
        kernelSize: 4,
        strides: 2,
        padding: 'same',
        activation: 'relu',
        kernelInitializer: 'randomNormal'
    }));

    // Converting to [0, 1]

    /*model.add(tf.layers.conv2d({
        filters: 3,
        kernelSize: 1,
        activation: 'sigmoid',
        kernelInitializer: 'randomNormal'
    }));*/

    // Extra

    if(forTraining){
        model.compile({
            optimizer: tf.train.adam(),
            loss: tf.losses.meanSquaredError,
            metrics: ['mse'],
        });
    }

    return model
}

class Generator {
    model;

    #canvas;

    constructor(canvas) {
        this.#canvas = canvas
    }

    async DenoiseImage(image) {
        // Albedo
        // First hit normals
        // Reflected normals
        // 

        const realInput = tf.tensor(image, [1, this.#canvas.height, this.#canvas.width, 3])

        const newImageTensor = await this.model.predict(realInput)
        const newImage = await newImageTensor.data()


        realInput.dispose()
        newImageTensor.dispose()

        return Float32Array.from(newImage);
    }

    async Init(forTraining) {
        this.model = makeGeneratorCore(forTraining);

        // Heat up the denoiser

        const randomImage = Float32Array.from(await tf.randomNormal([1, this.#canvas.height, this.#canvas.width, 3]).data());
        await this.DenoiseImage(randomImage)
    }
}

export default Generator
export { Generator }