import * as tf from '@tensorflow/tfjs';
import '@tensorflow/tfjs-backend-webgpu';

tf.setBackend('webgpu')

/*function makeGeneratorCore(){
    const coreModel = tf.sequential();

    // conv2d from getting important data
    // maxPooling2D to making the data smaller so that the model can learn

    coreModel.add(tf.layers.conv2d({
        filters: 32,
        kernelSize: 3,
        activation: 'relu',
        inputShape: [null, null, 3]
    }));

    coreModel.add(tf.layers.maxPooling2d({
        poolSize: [2, 2]
    }));

    coreModel.add(tf.layers.conv2d({
        filters: 64,
        kernelSize: 3,
        activation: 'relu'
    }));
    
    coreModel.add(tf.layers.maxPooling2d({
        poolSize: [2, 2]
    }));

    // Make it compatible for dense layers

    coreModel.add(tf.layers.globalAveragePooling2d({ dataFormat: 'channelsLast' }));

    // Actual denoise

    coreModel.add(tf.layers.dense({ units: 256, activation: 'LeakyReLU' }));
    coreModel.add(tf.layers.dense({ units: 128, activation: 'ReLU' }));

    // Transform the denoising neuron's data to a image compatible format

    // Add inputs

    const inputLayer = tf.layers.input({ shape: [null, null, 3] });
    const outputLayer = coreModel.apply(inputLayer);

    return tf.model({ inputs: inputLayer, outputs: outputLayer } )
}*/

function makeGeneratorCore(){
    const coreModel = tf.sequential();

    // conv2d from getting important data
    // maxPooling2D to making the data smaller so that the model can learn

    coreModel.add(tf.layers.conv2d({
        filters: 32,
        kernelSize: 3,
        activation: 'relu',
        inputShape: [null, null, 3]
    }));

    coreModel.add(tf.layers.maxPooling2d({
        poolSize: [2, 2]
    }));

    coreModel.add(tf.layers.conv2d({
        filters: 64,
        kernelSize: 3,
        activation: 'relu'
    }));
    
    coreModel.add(tf.layers.maxPooling2d({
        poolSize: [2, 2]
    }));

    // Make it compatible for dense layers

    coreModel.add(tf.layers.globalAveragePooling2d({ dataFormat: 'channelsLast' }));

    // Actual denoise

    coreModel.add(tf.layers.dense({ units: 256, activation: 'LeakyReLU' }));
    coreModel.add(tf.layers.dense({ units: 128, activation: 'ReLU' }));

    // Transform the denoising neuron's data to a image compatible format

    // Add inputs

    const inputLayer = tf.layers.input({ shape: [null, null, 3] });
    const outputLayer = coreModel.apply(inputLayer);

    return tf.model({ inputs: inputLayer, outputs: outputLayer } )
}

class Generator {
    model;
    //noiseInput;

    #canvas;
    //#canvasLastHeight;
    //#canvasLastWidth;

    constructor(canvas) {
        this.#canvas = canvas
    }

    async DenoiseImage(image){
        // Albedo
        // First hit normals
        // Reflected normals
        // 

        // making random noise if needed

        /*if(this.#canvasLastHeight !== this.#canvas.height || this.#canvasLastWidth !== this.#canvas.width){
            this.#canvasLastHeight = this.#canvas.height
            this.#canvasLastWidth = this.#canvas.width

            //this.noiseInput = tf.randomNormal([1, this.#canvas.height, this.#canvas.width, 3]);
        }*/

        // Creating the real input
        
        const realInput = tf.concat([
            //this.noiseInput, 
            tf.tensor(image, [1, this.#canvas.height, this.#canvas.width, 3]),
        ], 1)

        // Getting the new image

        const newImageTensor = await this.model.predict(realInput)
        const newImage = await newImageTensor.data()

        // Transforming it into a actual image

        

        // Cleaning up

        realInput.dispose()
        newImageTensor.dispose()

        return Float32Array.from(newImage);
    }

    async Init() {
        this.model = makeGeneratorCore();

        // Heat up the denoiser

        const randomImage = Float32Array.from(await tf.randomNormal([1, this.#canvas.height, this.#canvas.width, 3]).data());
        await this.DenoiseImage(randomImage)
    }
}

class Discriminator {
    model;

    constructor() {

    }

    async Init() {
        await new Promise((resolve, reject) => {
            let interval = setInterval(() => {
                if (!tf_loaded) return;

                clearInterval(interval)
                resolve()
            }, 100)
        })

        this.model = tf.sequential({
            layers: [
                tf.layers.conv2d({
                    filters: 256, // how many features to detect
                    kernelSize: 8, // size of the kernel
                    strides: 4, // how many pixels to move in a direction when moving the kernel
                    padding: "same",
                    inputShape: [null, null, 3]
                })
            ]
        })
    }
}


export default Generator
export { Generator, Discriminator }