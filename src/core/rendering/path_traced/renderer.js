//import Denoiser from "./denoiser.js"

import Vector3 from "../../classes/Vector3";
import BVHTree from "../../classes/bvh";

import ATrousDenoiser from "./denoiser/ATrous";
import emptyDenoiser from "./denoiser/none";
import TensorflowDenoiser from "./denoiser/tensorflow"

let octreeBranchStride = 4 + 4 + 4 + 8;

function getNext2Power(n) {
    return Math.pow(2, Math.ceil(Math.log2(n + 1)));
}

class PathTracedRenderer {
    // globals

    UpdateDataBuffer = false;
    parent;

    // compute pipeline

    computePipeline;
    renderPipeline;

    computeDataBindGroup;
    computeMapBindGroup;
    computeImageBindGroup;

    computeDataLayout;
    computeMapLayout;
    computeImageLayout;

    renderTextureColor;
    renderTextureReadColor;

    renderTextureNormal;
    renderTextureReadNormal;

    renderTextureDepth;
    renderTextureReadDepth;
    renderTextureAlbedo;
    renderTextureReadAlbedo;
    renderTextureObject;

    renderTextureHistory;
    renderTextureHistoryRead;
    renderHistoryData

    temporalBuffer;
    renderDenoisedTexture;
    renderReadTexture;

    computeGlobalData;
    computeMapData;
    computeOctreeTreeData;

    // Renderer Data

    bounces = 5;
    rpp = 3;

    denoiser = "none"
    denoisersBuilt = {}

    constructor(parent) {
        this.parent = parent;
    }

    async loadDenoiser(name){
        let denoisersByName = {
            "none": emptyDenoiser,
            "atrous": ATrousDenoiser,
            "tensorflow": TensorflowDenoiser,
        }

        this.denoisersBuilt[name] = new denoisersByName[name](this.parent, this);
        await this.denoisersBuilt[name].makePipelines()
    }

    unloadDenoiser(name){
        delete this.denoisersBuilt[name];
    }

    internal__makeBindGroups() {
        /*
            Pixel:

            Noisy Image - 4 channels (r, g, b, w)
            Normal Image - 4 channels (r, g, b, w)
            Velocity Image - 4 channels (r, g, b, w)
        */

        /*
            Temportal Pixel

            Velocity - 4 channels (r, g, b, w)
        */

        // render textures

        let TextureSize = (this.parent.canvas.width * this.parent.canvas.height * 4) * 4;
        let ComputeSize = TextureSize * 3;
        let TemportalSize = TextureSize * 1;

        this.renderTextureReadDenoised = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureColor = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureNormal = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureDepth = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureAlbedo = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureObject = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'r32float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureHistory = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba32float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureHistoryRead = this.parent.device.createTexture({
            label: "renderTextureHistoryRead",
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba32float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderDenoisedTexture = this.parent.device.createTexture({
            size: { width: this.parent.canvas.width, height: this.parent.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderHistoryData = this.parent.device.createBuffer({
            size: 8,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });

        this.temporalBuffer = this.parent.device.createBuffer({
            size: TemportalSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.renderReadTexture = this.parent.device.createBuffer({
            size: ComputeSize,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
        });

        // Data

        this.computeGlobalData = this.parent.device.createBuffer({
            size: 128,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
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

        this.computeMapBindGroup = this.parent.device.createBindGroup({
            layout: this.computeMapLayout,
            label: "Browzium Engine compute shader map bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.parent.computeMapData,
                    },
                },
                {
                    binding: 1,
                    resource: {
                        buffer: this.parent.computeLightData,
                    }
                },
                {
                    binding: 2,
                    resource: {
                        buffer: this.parent.computeMaterialData,
                    },
                },
                {
                    binding: 3,
                    resource: {
                        buffer: this.computeOctreeTreeData,
                    },
                },
                {
                    binding: 4,
                    resource: this.parent.textureAtlas.createView(),
                },
                {
                    binding: 5,
                    resource: this.parent.textureAtlasSampler,
                },
                {
                    binding: 6,
                    resource: this.parent.worldTexture.createView(),
                },
                {
                    binding: 7,
                    resource: this.parent.worldTextureSampler,
                }
            ],
        });

        this.fragmentBindGroup = this.parent.device.createBindGroup({
            layout: this.fragmentImageLayout,
            label: "Browzium Engine fragment shader bind group",
            entries: [
                {
                    binding: 0,
                    resource: this.renderTextureReadDenoised.createView(), // TODO: FIX
                },
                {
                    binding: 1,
                    resource: this.renderTextureHistory.createView(),
                },
                {
                    binding: 2,
                    resource: this.renderTextureHistoryRead.createView(),
                }
            ],
        });

        this.computeImageBindGroup = this.parent.device.createBindGroup({
            layout: this.computeImageLayout,
            label: "Browzium Engine compute shader image bind group",
            entries: [
                {
                    binding: 0,
                    resource: this.renderTextureColor.createView(),
                },
                {
                    binding: 1,
                    resource: this.renderTextureNormal.createView(),
                },
                {
                    binding: 2,
                    resource: this.renderTextureDepth.createView(),
                },
                {
                    binding: 3,
                    resource: this.renderTextureAlbedo.createView(),
                },
                {
                    binding: 4,
                    resource: this.renderTextureObject.createView(),
                }
            ],
        });

        this.renderHistoryDataBindGroup = this.parent.device.createBindGroup({
            layout: this.frameDataLayout,
            label: "Browzium Engine compute shader image bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.renderHistoryData,
                    },
                }
            ],
        });
    }

    internal__makePipelines() {
        const computeShader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.path_traced.compute, label: "Browzium engine compute shader code" });
        const fragmentShader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.path_traced.fragment, label: "Browzium engine fragment shader code" });
        const vertexShader = this.parent.device.createShaderModule({ code: this.parent.opts.shaders.path_traced.vertex, label: "Browzium engine vertex shader code" });

        this.computeDataLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
            ],
        });

        this.computeMapLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    },
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE,
                    buffer: {
                        type: "read-only-storage",
                    }
                },
                {
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                        multisampled: false,
                        viewDimension: "2d-array",
                    }
                },
                {
                    binding: 5,
                    visibility: GPUShaderStage.COMPUTE,
                    sampler: {},
                },
                {
                    binding: 6,
                    visibility: GPUShaderStage.COMPUTE,
                    texture: {
                        format: "rgba16float",
                        multisampled: false,
                        viewDimension: "2d",
                    }
                },
                {
                    binding: 7,
                    visibility: GPUShaderStage.COMPUTE,
                    sampler: {},
                }
            ],
        });

        this.computeImageLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 3,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 4,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "write-only",
                        format: "r32float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                }
            ],
        });

        this.frameDataLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "read-only-storage",
                    },
                }
            ],
        });

        this.fragmentImageLayout = this.parent.device.createBindGroupLayout({
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    texture: {
                        format: "rgba16float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    storageTexture: {
                        access: "write-only",
                        format: "rgba32float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
                    texture: {
                        format: "rgba32float",
                        viewDimension: "2d",
                        multisampled: false,
                    }
                },
            ],
        });

        let pipelineLayout = this.parent.device.createPipelineLayout({
            bindGroupLayouts: [this.computeDataLayout, this.computeMapLayout, this.computeImageLayout, this.frameDataLayout],
            label: "Browzium Engine Pipeline Layout",
        })

        let fragmentPipelineLayout = this.parent.device.createPipelineLayout({
            bindGroupLayouts: [this.computeDataLayout, this.fragmentImageLayout, this.frameDataLayout],
            label: "Browzium Engine Pipeline Layout",
        })

        this.computePipeline = this.parent.device.createComputePipeline({
            layout: pipelineLayout,
            label: "Browzium Engine Compute Pipeline",
            compute: {
                module: computeShader,
                entryPoint: "computeMain",
            },
        });

        this.renderPipeline = this.parent.device.createRenderPipeline({
            layout: fragmentPipelineLayout,
            label: "Browzium Engine Render Pipeline",
            vertex: {
                module: vertexShader,
                entryPoint: 'vertexMain',
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
            }
        })
    }

    async generateImage() {

        // Run the compute shader

        const commandEncoder = this.parent.device.createCommandEncoder();

        const passEncoder = commandEncoder.beginComputePass();

        passEncoder.setPipeline(this.computePipeline);

        passEncoder.setBindGroup(0, this.computeDataBindGroup);
        passEncoder.setBindGroup(1, this.computeMapBindGroup);
        passEncoder.setBindGroup(2, this.computeImageBindGroup);
        passEncoder.setBindGroup(3, this.renderHistoryDataBindGroup);

        passEncoder.dispatchWorkgroups(Math.ceil(this.parent.canvas.width / 16), Math.ceil(this.parent.canvas.height / 16), 1); //  Z for SPP
        passEncoder.end();

        this.parent.device.queue.submit([commandEncoder.finish()]);
        await this.parent.device.queue.onSubmittedWorkDone()

        // Denoise

        if (!this.denoisersBuilt[this.denoiser]) {
            throw new Error(`${this.denoiser} is not a available denoiser.`)
        }

        await this.denoisersBuilt[this.denoiser].denoise()
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
        // Copy the history buffer

        const copyEncoder = this.parent.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: this.renderTextureHistory,
            },
            {
                texture: this.renderTextureHistoryRead,
            },
            {
                width: this.parent.canvas.width,
                height: this.parent.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        this.parent.device.queue.submit([copyEncoder.finish()]);

        // Write image to screen

        const commandEncoder = this.parent.device.createCommandEncoder();
        const currentTexture = this.parent.context.getCurrentTexture();

        const passEncoder = commandEncoder.beginRenderPass({
            colorAttachments: [{
                view: currentTexture.createView(),
                loadValue: { r: 0.0, g: 0, b: 0.0, a: 1.0 },
                loadOp: "clear",
                storeOp: 'store',
            }],
            label: "Browzium render pass"
        });

        passEncoder.setPipeline(this.renderPipeline);

        passEncoder.setBindGroup(0, this.computeDataBindGroup);
        passEncoder.setBindGroup(1, this.fragmentBindGroup);
        passEncoder.setBindGroup(2, this.renderHistoryDataBindGroup);

        passEncoder.draw(6, 2, 0, 0);
        passEncoder.end();

        this.parent.device.queue.submit([commandEncoder.finish()]);
    }

    UpdateData() {
        let computeGlobalData = new Float32Array([
            this.parent.canvas.width,
            this.parent.canvas.height,

            this.parent.Camera.FieldOfView,
            //this.rpp,
            //this.bounces,
            this.parent.focalLength,

            this.parent.Camera.Position.x,
            this.parent.Camera.Position.y,
            this.parent.Camera.Position.z,
            this.parent.apertureSize,

            ...this.parent.Camera.CameraToWorldMatrix.getContents(),

            this.parent.tonemapMode,
            this.parent.gammaCorrect,
            //0,
            //0
        ])

        this.parent.Camera.wasCameraUpdated = false;
        this.UpdateDataBuffer = false;
        this.parent.device.queue.writeBuffer(this.computeGlobalData, 0, computeGlobalData, 0, computeGlobalData.length);
    }

    UpdateRenderData() {
        let renderData = new Float32Array([
            this.parent.staticFrames,
            this.parent.frame
        ])

        this.parent.device.queue.writeBuffer(this.renderHistoryData, 0, renderData, 0, renderData.length);
    }

    CreateOctree(triangleArray) {
        if (triangleArray.length == 0) {
            return [new BVHTree(new Vector3(0, 0, 0), new Vector3(0, 0, 0), [])];
        }

        /*let octree = new Octree()
        let branches = []*/

        let octreeSize = BVHTree.calculateTreeSize(triangleArray)
        let octree = new BVHTree(octreeSize.minPosition, octreeSize.maxPosition, triangleArray, triangleArray)

        let branches = []
        function getBranches(leaf) {
            branches.push(leaf)

            if (leaf.child1) {
                let len = branches.length
                getBranches(leaf.child1)
                leaf.child1 = len;
            }

            if (leaf.child2) {
                let len = branches.length
                getBranches(leaf.child2)
                leaf.child2 = len;
            }
        }

        getBranches(octree)

        return branches
    }

    internal__SetOctree(triangleArray, updateBuffer) {
        let octree = this.CreateOctree(triangleArray)

        let oldSize = (this.computeOctreeTreeData || { size: 0 }).size / 4
        let newSize = getNext2Power(octree.length) * octreeBranchStride

        let octreeData = new Float32Array(newSize);

        if (newSize > oldSize) {
            this.computeOctreeTreeData = this.parent.device.createBuffer({
                size: octreeData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (updateBuffer) {
                this.internal__makeBindGroups()
            }
        }

        for (let branchIndex = 0; branchIndex < octree.length; branchIndex++) {
            let octreeBranch = octree[branchIndex]
            let locationStart = octreeBranchStride * branchIndex;

            // minPosition

            octreeData[locationStart + 0] = octreeBranch.minPosition.x;
            octreeData[locationStart + 1] = octreeBranch.minPosition.y;
            octreeData[locationStart + 2] = octreeBranch.minPosition.z;
            octreeData[locationStart + 3] = 0;

            // maxPosition

            octreeData[locationStart + 4] = octreeBranch.maxPosition.x;
            octreeData[locationStart + 5] = octreeBranch.maxPosition.x;
            octreeData[locationStart + 6] = octreeBranch.maxPosition.x;
            octreeData[locationStart + 7] = 0;

            // Children

            octreeData[locationStart + 8] = isNaN(octreeBranch.child1) ? -1 : octreeBranch.child1;
            octreeData[locationStart + 9] = isNaN(octreeBranch.child2) ? -1 : octreeBranch.child2;
            octreeData[locationStart + 10] = 0;
            octreeData[locationStart + 11] = 0;

            // Triangles

            for (let i = 0; i < 8; i++) {
                octreeData[locationStart + 12 + i] = isNaN(octreeBranch.objects[i]) ? -1 : octreeBranch.objects[i];
            }
        }

        this.parent.device.queue.writeBuffer(this.computeOctreeTreeData, 0, octreeData, 0, octreeData.length);
    }

    SetTriangles(triangleArray) {
        this.internal__SetOctree(triangleArray, true)
    }

    async RenderFrame(readImage) {
        let output = {}

        if (this.parent.Camera.wasCameraUpdated || this.UpdateDataBuffer) {
            this.UpdateData();
        }

        this.UpdateRenderData()

        let generateStart = Date.now()
        await this.generateImage();
        output.traceTime = Date.now() - generateStart;

        // denoise

        if (!this.denoisersBuilt[this.denoiser]) {
            throw new Error(`${this.denoiser} is not a available denoiser.`)
        }

        await this.denoisersBuilt[this.denoiser].denoise()

        // render

        await this.renderImage();

        if (readImage) {
            output.image = this.readImage()
        }

        return output;
    }

    ResolutionChange(){
        for (const denoiserName in this.denoisersBuilt) {
            if (this.denoisersBuilt.hasOwnProperty(denoiserName)) {
                this.denoisersBuilt[denoiserName].makeBindGroups()
            }
        }

        this.internal__makeBindGroups()
        this.UpdateDataBuffer = true;
    }

    async Init() {
        this.internal__SetOctree([], false);
        this.internal__makePipelines();
        this.internal__makeBindGroups();

        this.loadDenoiser("none")

        //this.UpdateData();

        //await this.#Denoiser.Init()
    }
}

export default PathTracedRenderer