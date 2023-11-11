//import Denoiser from "./denoiser.js"

/*
    Triangle struct:

    a, b, c - 3 * 4 * 4
    na, nb, nc - 3 * 4 * 4
*/

let vertexSize = 4;
let triangleStride = (vertexSize * 3) + (vertexSize * 3);

function getNext2Power(n) {
    return Math.pow(2, Math.ceil(Math.log2(n + 1)));
}

class RenderingManager {
    // globals

    opts;
    canvas;
    #lastCanvasSize = { width: 0, height: 0 }

    // raw gpu context

    adapter;
    device;
    context;

    presentationFormat;

    // compute pipeline

    computePipeline
    #computeLayout
    #computeBindGroup

    #renderTexture;
    #renderReadTexture;

    #computeGlobalData;
    #computeMapData;

    // Camera

    #Camera

    // Denoiser

    #Denoiser

    constructor(opts = {}, Camera) {
        if (!navigator.gpu) {
            throw Error("WebGPU not supported.");
        }

        if (!opts.canvas || !(opts.canvas instanceof HTMLCanvasElement)) {
            throw Error("Canvas should be a HTMLCanvasElement!")
        }

        this.canvas = opts.canvas;
        this.opts = opts;

        this.#Camera = Camera

        //this.#Denoiser = new Denoiser(opts.canvas)
    }

    async #makeBindGroups() {
        /*
            Albedo - 3 channels (r, g, b)

        */

        // render textures

        let TextureSize = this.canvas.width * this.canvas.height * 3 * 4;
        let ComputeSize = TextureSize * 1;

        this.#renderTexture = this.device.createBuffer({
            size: ComputeSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.#renderReadTexture = this.device.createBuffer({
            size: ComputeSize,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
        });

        // Data

        this.#computeGlobalData = this.device.createBuffer({
            size: 96,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });


        // Bind groups

        this.#computeBindGroup = this.device.createBindGroup({
            layout: this.#computeLayout,
            label: "Browzium Engine compute shader bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.#renderTexture,
                    },
                },
                {
                    binding: 1,
                    resource: {
                        buffer: this.#computeGlobalData,
                    },
                },
                {
                    binding: 2,
                    resource: {
                        buffer: this.#computeMapData,
                    },
                },
            ],
        });
    }

    async #makePipelines() {
        // Compute

        const computeShader = this.device.createShaderModule({ code: this.opts.shaders.compute, label: "Browzium compute shader" });

        this.#computeLayout = this.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "storage",
                    },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
            ],
        });

        this.computePipeline = this.device.createComputePipeline({
            layout: this.device.createPipelineLayout({
                bindGroupLayouts: [this.#computeLayout],
                label: "Browzium Engine Compute Pipeline Layout",
            }),
            label: "Browzium Engine Compute Pipeline",
            compute: {
                module: computeShader,
                entryPoint: "main",
            },
        });
    }

    async #generateImage() {

        // Run the compute shader

        const commandEncoder = this.device.createCommandEncoder();

        const passEncoder = commandEncoder.beginComputePass();

        passEncoder.setPipeline(this.computePipeline);
        passEncoder.setBindGroup(0, this.#computeBindGroup);
        passEncoder.dispatchWorkgroups(Math.ceil(this.canvas.width / 8), Math.ceil(this.canvas.height / 8), 1); //  Z for SPP
        passEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone()

        // Read the results

        const copyCommandEncoder = this.device.createCommandEncoder();
        copyCommandEncoder.copyBufferToBuffer(this.#renderTexture, 0, this.#renderReadTexture, 0, this.#renderReadTexture.size);
        this.device.queue.submit([copyCommandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone();

        await this.#renderReadTexture.mapAsync(GPUMapMode.READ);

        const arrayBuffer = this.#renderReadTexture.getMappedRange();
        const data = new Float32Array(new Float32Array(arrayBuffer));

        this.#renderReadTexture.unmap();

        return data
    }

    async #renderImage(image) {
        //console.log(image)

        // Write image to scren

        const imageData = this.context.createImageData(this.canvas.width, this.canvas.height);
        
        let size = image.length / 3;
        for (let i = 0; i < size; i ++) {
            const index = i * 4;
            const rawIndex = i * 3;

            imageData.data[index] = image[rawIndex] * 255;
            imageData.data[index + 1] = image[rawIndex + 1] * 255;
            imageData.data[index + 2] = image[rawIndex + 2] * 255;
            imageData.data[index + 3] = 255;
        }

        this.context.putImageData(imageData, 0, 0);
    }

    #UpdateData() {
        let computeGlobalData = new Float32Array([
            this.canvas.width,
            this.canvas.height,
            
            this.#Camera.FieldOfView,
            0,

            this.#Camera.Position.x,
            this.#Camera.Position.y,
            this.#Camera.Position.z,
            0,

            ...this.#Camera.CameraToWorldMatrix.getContents()
        ])

        this.#Camera.wasCameraUpdated = false;
        this.device.queue.writeBuffer(this.#computeGlobalData, 0, computeGlobalData, 0, computeGlobalData.length);
    }

    async SetTriangles(triangleArray, dontUpdateBuffer) {
        let oldSize = (this.#computeMapData || { size: 0 }).size
        let newSize = getNext2Power(triangleArray.length) * triangleStride

        let startIndex = 1;
        let totalSize = startIndex + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let triangleData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.#computeMapData = this.device.createBuffer({
                size: triangleData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if(!dontUpdateBuffer){
                await this.#makeBindGroups()
            }
        }

        triangleData[0] = triangleArray.length

        for (let triIndex = 0; triIndex < triangleArray.length; triIndex++) {
            let triangle = triangleArray[triIndex]
            let locationStart = triangleStride * triIndex + startIndex;

            // Vertices

            triangleData[locationStart + 0] = triangle.a.x;
            triangleData[locationStart + 1] = triangle.a.y;
            triangleData[locationStart + 2] = triangle.a.z;
            triangleData[locationStart + 3] = 0;

            triangleData[locationStart + 4] = triangle.b.x;
            triangleData[locationStart + 5] = triangle.b.y;
            triangleData[locationStart + 6] = triangle.b.z;
            triangleData[locationStart + 7] = 0;

            triangleData[locationStart + 8] = triangle.c.x;
            triangleData[locationStart + 9] = triangle.c.y;
            triangleData[locationStart + 10] = triangle.c.z;
            triangleData[locationStart + 11] = 0;

            // Normals

            triangleData[locationStart + 12] = triangle.na.x;
            triangleData[locationStart + 13] = triangle.na.y;
            triangleData[locationStart + 14] = triangle.na.z;
            triangleData[locationStart + 15] = 0;

            triangleData[locationStart + 16] = triangle.nb.x;
            triangleData[locationStart + 17] = triangle.nb.y;
            triangleData[locationStart + 18] = triangle.nb.z;
            triangleData[locationStart + 19] = 0;

            triangleData[locationStart + 20] = triangle.nc.x;
            triangleData[locationStart + 21] = triangle.nc.y;
            triangleData[locationStart + 22] = triangle.nc.z;
            triangleData[locationStart + 23] = 0;
        }

        console.log(triangleData, triangleStride)

        this.device.queue.writeBuffer(this.#computeMapData, 0, triangleData, 0, triangleData.length);
    }

    async RenderFrame() {
        if (this.canvas.width !== this.#lastCanvasSize.width || this.canvas.height !== this.#lastCanvasSize.height) {
            this.#lastCanvasSize = { width: this.canvas.width, height: this.canvas.height }

            await this.#makeBindGroups()
            this.#Camera.wasCameraUpdated = false;
        }

        if(this.#Camera.wasCameraUpdated){
            this.#UpdateData();
        }

        let imageData = await this.#generateImage();
        await this.#renderImage(imageData);

        /*let imageData = await this.#generateImage();
        let denoisedImage = await this.#Denoiser.DenoiseImage(imageData)
        await this.#renderImage(denoisedImage);*/
    }

    async Init() {
        this.context = this.canvas.getContext('2d');
        this.adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
        if (!this.adapter) {
            throw Error("Couldn't request WebGPU adapter.");
        }

        this.device = await this.adapter.requestDevice({ label: "Browzium GPU Device" });
        this.presentationFormat = await navigator.gpu.getPreferredCanvasFormat();

        await this.SetTriangles([], true);
        await this.#makePipelines();
        await this.#makeBindGroups();
        this.#UpdateData();

        //await this.#Denoiser.Init()
    }
}

export default RenderingManager