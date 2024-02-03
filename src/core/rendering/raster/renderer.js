//import Denoiser from "./denoiser.js"

import Vector3 from "../../classes/Vector3";

let triangleStride = 36;

function getNext2Power(n) {
    return Math.pow(2, Math.ceil(Math.log2(n + 1)));
}

function setVertice(array, index, materialIndex, objectId, position, normal, uv){
    array[index + 0] = position.x;
    array[index + 1] = position.y;
    array[index + 2] = position.z;
    array[index + 3] = 1;

    // normal

    array[index + 4] = normal.x;
    array[index + 5] = normal.y;
    array[index + 6] = normal.z;
    array[index + 7] = 0;

    // uvs

    array[index + 8] = uv.x;
    array[index + 9] = uv.y;
    array[index + 10] = materialIndex;
    array[index + 11] = objectId;
}

const vertexBuffersDescriptors = [
    {
        attributes: [
            {
                shaderLocation: 0,
                offset: 0,
                format: "float32x4",
            },
            {
                shaderLocation: 1,
                offset: 16,
                format: "float32x4",
            },
            {
                shaderLocation: 2,
                offset: 32,
                format: "float32x4",
            },
        ],
        arrayStride: 48,
        stepMode: "vertex",
    },
];

class RasterRenderer {
    // globals

    UpdateDataBuffer = false;
    parent;

    // compute pipeline

    computePipeline;
    renderPipeline;

    computeDataLayout

    // world map

    computeGlobalData;
    computeMapData;

    // Renderer Data

    constructor(parent) {
        this.parent = parent;
    }

    internal__makeBindGroups() {

        // render textures

        this.computeGlobalData = this.parent.device.createBuffer({
            size: 64,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });

        this.depthTexture = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT,
        });

        // Bind groups

        this.computeDataBindGroup = this.parent.device.createBindGroup({
            layout: this.computeDataLayout,
            label: "Browzium Engine compute shader data bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.computeGlobalData,
                    },
                }
            ],
        });
    }

    internal__makePipelines() {
        //const computeShader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.raster.compute, label: "Browzium engine compute shader code" });
        const fragmentShader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.raster.fragment, label: "Browzium engine fragment shader code" });
        const vertexShader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.raster.vertex, label: "Browzium engine vertex shader code" });

        this.computeDataLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
            ],
        });

        let fragmentPipelineLayout = this.parent.device.createPipelineLayout({
            bindGroupLayouts: [this.computeDataLayout],
            label: "Browzium Engine Pipeline Layout",
        })

        this.renderPipeline = this.parent.device.createRenderPipeline({
            layout: fragmentPipelineLayout,
            label: "Browzium Engine Render Pipeline",
            vertex: {
                module: vertexShader,
                entryPoint: 'vertexMain',
                buffers: vertexBuffersDescriptors,
            },
            fragment: {
                module: fragmentShader,
                entryPoint: 'fragmentMain',
                targets: [
                    {
                        format: this.parent.presentationFormat,
                    },
                ],
            },
            primitive: {
                topology: 'triangle-list',
            },
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus",
            },
        })
    }

    async readImage() {
        const copyCommandEncoder = this.parent.device.createCommandEncoder();
        copyCommandEncoder.copyBufferToBuffer(this.renderTextureColor, 0, this.renderReadTexture, 0, this.renderReadTexture.size);
        this.parent.device.queue.submit([copyCommandEncoder.finish()]);
        await this.parent.device.queue.onSubmittedWorkDone();

        await this.renderReadTexture.mapAsync(GPUMapMode.READ);

        const arrayBuffer = this.renderReadTexture.getMappedRange();
        const data = new Float32Array(new Float32Array(arrayBuffer));

        this.renderReadTexture.unmap();

        return data
    }

    async renderImage() {
        if (!this.computeMapData) return;

        const commandEncoder = this.parent.device.createCommandEncoder();
        const currentTexture = this.parent.context.getCurrentTexture();

        const passEncoder = commandEncoder.beginRenderPass({
            colorAttachments: [{
                view: currentTexture.createView(),
                loadValue: { r: 0.0, g: 0, b: 0.0, a: 1.0 },
                loadOp: "clear",
                storeOp: 'store',
            }],
            depthStencilAttachment: {
                view: this.depthTexture.createView(),
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store",
            },
            label: "Browzium render pass"
        });

        passEncoder.setPipeline(this.renderPipeline);
        passEncoder.setVertexBuffer(0, this.computeMapData);
        passEncoder.setBindGroup(0, this.computeDataBindGroup)

        //passEncoder.draw(3, 1);
        passEncoder.draw(this.parent.triangles.length * 3, this.parent.triangles.length);
        passEncoder.end();

        this.parent.device.queue.submit([commandEncoder.finish()]);
    }

    UpdateData() {
        let computeGlobalData = new Float32Array([
            /*this.parent.canvas.width,
            this.parent.canvas.height,

            this.parent.Camera.FieldOfView,
            //this.rpp,
            //this.bounces,
            this.focalLength,

            this.parent.Camera.Position.x,
            this.parent.Camera.Position.y,
            this.parent.Camera.Position.z,
            this.apertureSize,*/

            ...this.parent.Camera.CameraToWorldMatrix.getContents(),

            //this.tonemapMode,
            //this.gammaCorrect,
            //0,
            //0
        ])

        this.parent.Camera.wasCameraUpdated = false;
        this.UpdateDataBuffer = false;
        this.parent.device.queue.writeBuffer(this.computeGlobalData, 0, computeGlobalData, 0, computeGlobalData.length);
    }

    UpdateRenderData() {
        /*let renderData = new Float32Array([
            this.parent.staticFrames,
            this.parent.frame
        ])

        this.parent.device.queue.writeBuffer(this.renderHistoryData, 0, renderData, 0, renderData.length);*/
    }

    SetTriangles(triangleArray) {
        let oldSize = (this.computeMapData || { size: 0 }).size / 4
        let newSize = getNext2Power(triangleArray.length) * triangleStride

        let triangleData = new Float32Array(newSize);

        if (newSize > oldSize) {
            this.computeMapData = this.parent.device.createBuffer({
                size: triangleData.byteLength,
                usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
            });
        }

        let materialsKeys = Object.keys(this.parent.materials)
        let verticeIndex = 0;

        for (let triIndex = 0; triIndex < triangleArray.length; triIndex++) {
            let triangle = triangleArray[triIndex]
            let materialIndex = materialsKeys.indexOf(triangle.material)

            setVertice(triangleData, verticeIndex, materialIndex, triangle.objectId, triangle.a, triangle.na, triangle.uva);
            verticeIndex += 12;
            setVertice(triangleData, verticeIndex, materialIndex, triangle.objectId, triangle.b, triangle.nb, triangle.uvb);
            verticeIndex += 12;
            setVertice(triangleData, verticeIndex, materialIndex, triangle.objectId, triangle.c, triangle.nc, triangle.uvc);
            verticeIndex += 12;

            /*//// Vertex 1

            // position

            triangleData[locationStart + 0] = triangle.a.x;
            triangleData[locationStart + 1] = triangle.a.y;
            triangleData[locationStart + 2] = triangle.a.z;
            triangleData[locationStart + 3] = materialIndex; // material index

            // normal

            triangleData[locationStart + 4] = triangle.na.x;
            triangleData[locationStart + 5] = triangle.na.y;
            triangleData[locationStart + 6] = triangle.na.z;
            triangleData[locationStart + 7] = triangle.objectId;

            // uvs

            triangleData[locationStart + 8] = triangle.uva.x;
            triangleData[locationStart + 9] = triangle.uva.y;

            //// Vertex 2

            // position

            triangleData[locationStart + 12] = triangle.b.x;
            triangleData[locationStart + 13] = triangle.b.y;
            triangleData[locationStart + 14] = triangle.b.z;
            triangleData[locationStart + 15] = materialIndex; // material index

            // normal

            triangleData[locationStart + 16] = triangle.nb.x;
            triangleData[locationStart + 17] = triangle.nb.y;
            triangleData[locationStart + 18] = triangle.nb.z;
            triangleData[locationStart + 19] = triangle.objectId;

            // uvs

            triangleData[locationStart + 20] = triangle.uvb.x;
            triangleData[locationStart + 21] = triangle.uvb.y;

            //// Vertex 3

            // position

            triangleData[locationStart + 24] = triangle.c.x;
            triangleData[locationStart + 25] = triangle.c.y;
            triangleData[locationStart + 26] = triangle.c.z;
            triangleData[locationStart + 27] = materialIndex; // material index

            // normal

            triangleData[locationStart + 28] = triangle.nc.x;
            triangleData[locationStart + 29] = triangle.nc.y;
            triangleData[locationStart + 30] = triangle.nc.z;
            triangleData[locationStart + 31] = triangle.objectId;

            // uvs

            triangleData[locationStart + 32] = triangle.uvc.x;
            triangleData[locationStart + 33] = triangle.uvc.y;*/
        }

        /*triangleData = new Float32Array([
            -1.0, -1.0, 0, 1,  0, 0, 0, 0, 0, 0, 0, 0,
            -0.0, 1.0, 0, 1,  0, 0, 0, 0, 0, 0, 0, 0,
            1.0, -1.0, 0, 1,  0, 0, 0, 0, 0, 0, 0, 0
        ])*/

        console.log(triangleData, "tri data")

        this.parent.device.queue.writeBuffer(this.computeMapData, 0, triangleData, 0, triangleData.length);
    }

    async RenderFrame(readImage) {
        let output = {}

        if (this.parent.Camera.wasCameraUpdated || this.UpdateDataBuffer) {
            this.UpdateData();
        }

        this.UpdateRenderData()

        //let generateStart = Date.now()
        //await this.generateImage();
        //output.traceTime = Date.now() - generateStart;

        // render

        await this.renderImage();

        if (readImage) {
            output.image = this.readImage()
        }

        return output;
    }

    ResolutionChange() {
        this.internal__makeBindGroups()
        this.UpdateDataBuffer = true;
    }

    async Init() {
        this.internal__makePipelines();
        this.internal__makeBindGroups();
    }
}

export default RasterRenderer