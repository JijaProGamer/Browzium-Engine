//import Denoiser from "./denoiser.js"

import Vector3 from "../classes/Vector3";
import Vector2 from "../classes/Vector2";
import BVHTree from "../classes/bvh";

import ATrousDenoiser from "./denoiser/ATrous";
import emptyDenoiser from "./denoiser/none";
import TensorflowDenoiser from "./denoiser/tensorflow"

let triangleStride = (3 * 4) + (3 * 4) + (2 * 4);
let materialStride = 4 + 4 + 4 + 4;
let octreeBranchStride = 4 + 4 + 4 + 8;

function getNext2Power(n) {
    return Math.pow(2, Math.ceil(Math.log2(n + 1)));
}

class RenderingManager {
    // globals

    opts;
    canvas;
    UpdateDataBuffer = false;
    #lastCanvasSize = { width: 0, height: 0 }
    materials = [];

    // raw gpu context

    adapter;
    device;
    context;

    presentationFormat;

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
    computeLightData;
    computeMaterialData;
    computeOctreeTreeData;

    // Camera

    Camera

    // Renderer Data

    bounces = 5;
    rpp = 3;

    tonemapMode = 1;
    gammaCorrect = true;

    denoiser = "none"

    frame = 0;
    staticFrames = 0;

    focalLength = 0;
    apertureSize = 0;

    denoisersBuilt = {}

    // Texture Data

    textureAtlas;
    textureAtlasSampler;
    texturesContained;

    constructor(opts = {}, Camera) {
        if (!navigator.gpu) {
            throw Error("WebGPU not supported.");
        }

        if (!opts.canvas || !(opts.canvas instanceof HTMLCanvasElement)) {
            throw Error("Canvas should be a HTMLCanvasElement!")
        }

        this.canvas = opts.canvas;
        this.opts = opts;

        this.Camera = Camera
    }

    async loadDenoiser(name){
        let denoisersByName = {
            "none": emptyDenoiser,
            "atrous": ATrousDenoiser,
            "tensorflow": TensorflowDenoiser,
        }

        this.denoisersBuilt[name] = new denoisersByName[name](this);
        await this.denoisersBuilt[name].makePipelines()
    }

    unloadDenoiser(name){
        delete this.denoisersBuilt[name];
    }

    #makeBindGroups() {
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

        let TextureSize = (this.canvas.width * this.canvas.height * 4) * 4;
        let ComputeSize = TextureSize * 3;
        let TemportalSize = TextureSize * 1;

        this.renderTextureReadDenoised = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureColor = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureNormal = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureDepth = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureAlbedo = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureObject = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'r32float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureHistory = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba32float',
            usage: GPUTextureUsage.COPY_SRC | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderTextureHistoryRead = this.device.createTexture({
            label: "renderTextureHistoryRead",
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba32float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderDenoisedTexture = this.device.createTexture({
            size: { width: this.canvas.width, height: this.canvas.height },
            format: 'rgba16float',
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
        });

        this.renderHistoryData = this.device.createBuffer({
            size: 8,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });

        this.temporalBuffer = this.device.createBuffer({
            size: TemportalSize,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
        });

        this.renderReadTexture = this.device.createBuffer({
            size: ComputeSize,
            usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
        });

        // Data

        this.computeGlobalData = this.device.createBuffer({
            size: 128,
            usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
        });


        // Bind groups

        this.computeDataBindGroup = this.device.createBindGroup({
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

        this.computeMapBindGroup = this.device.createBindGroup({
            layout: this.computeMapLayout,
            label: "Browzium Engine compute shader map bind group",
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.computeMapData,
                    },
                },
                {
                    binding: 1,
                    resource: {
                        buffer: this.computeLightData,
                    }
                },
                {
                    binding: 2,
                    resource: {
                        buffer: this.computeMaterialData,
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
                    resource: this.textureAtlas.createView(),
                },
                {
                    binding: 5,
                    resource: this.textureAtlasSampler,
                },
                {
                    binding: 6,
                    resource: this.worldTexture.createView(),
                },
                {
                    binding: 7,
                    resource: this.worldTextureSampler,
                }
            ],
        });

        this.fragmentBindGroup = this.device.createBindGroup({
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

        this.computeImageBindGroup = this.device.createBindGroup({
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

        this.renderHistoryDataBindGroup = this.device.createBindGroup({
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

    #makePipelines() {
        const computeShader = this.device.createShaderModule({ code: this.opts.shaders.compute, label: "Browzium engine compute shader code" });
        const fragmentShader = this.device.createShaderModule({ code: this.opts.shaders.fragment, label: "Browzium engine fragment shader code" });
        const vertexShader = this.device.createShaderModule({ code: this.opts.shaders.vertex, label: "Browzium engine vertex shader code" });

        this.computeDataLayout = this.device.createBindGroupLayout({
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

        this.computeMapLayout = this.device.createBindGroupLayout({
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

        this.computeImageLayout = this.device.createBindGroupLayout({
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

        this.frameDataLayout = this.device.createBindGroupLayout({
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

        this.fragmentImageLayout = this.device.createBindGroupLayout({
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

        let pipelineLayout = this.device.createPipelineLayout({
            bindGroupLayouts: [this.computeDataLayout, this.computeMapLayout, this.computeImageLayout, this.frameDataLayout],
            label: "Browzium Engine Pipeline Layout",
        })

        let fragmentPipelineLayout = this.device.createPipelineLayout({
            bindGroupLayouts: [this.computeDataLayout, this.fragmentImageLayout, this.frameDataLayout],
            label: "Browzium Engine Pipeline Layout",
        })

        this.computePipeline = this.device.createComputePipeline({
            layout: pipelineLayout,
            label: "Browzium Engine Compute Pipeline",
            compute: {
                module: computeShader,
                entryPoint: "computeMain",
            },
        });

        this.renderPipeline = this.device.createRenderPipeline({
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
                        format: this.presentationFormat,
                    },
                ],
            },
            primitive: {
                topology: 'triangle-list',
            }
        })
    }

    #computeAtlasFormat(triangles) { // actually implement this xd
        let maxSize = 4096;
        //let maxSize = this.device.limits.maxTextureDimension2D
        let maxDepth = this.device.limits.maxTextureArrayLayers

        let textures = [[]]

        for (let materialName of Object.keys(this.materials)) {
            let material = this.materials[materialName]
            if (material.diffuseTexture.bitmap.length == 0) { continue; }

            let start = new Vector3(0, 0, 0);
            let resolution = material.diffuseTexture.resolution;
            let spaceFound = false;

            for(let textureIndex = 0; textureIndex < textures.length; textureIndex += 1){
                let atlas = textures[textureIndex];

                for (let x = 0; x <= maxSize - resolution.x; x += 1) {
                    for (let y = 0; y <= maxSize - resolution.y; y += 1) {
                        let isSpaceFree = true;
    
                        for (let tex of atlas) {
                            if (x < tex.x + tex.width &&
                                x + resolution.x > tex.x &&
                                y < tex.y + tex.height &&
                                y + resolution.y > tex.y) {
                                isSpaceFree = false;
                                break;
                            }
                        }
    
                        if (isSpaceFree) {
                            start.x = x;
                            start.y = y;
                            start.z = textureIndex;

                            spaceFound = true;
                            break;
                        }
                    }
    
                    if (spaceFound) {
                        break;
                    }
                }
    
                if (spaceFound) {
                    break;
                }
            }

            if(!spaceFound){
                start.z = textures.length;
                textures[start.z].push([])
            }

            material.diffuseTexture.atlasInfo.depth = start.z;
            material.diffuseTexture.atlasInfo.start = new Vector2(start.x / maxSize, start.y / maxSize);
            material.diffuseTexture.atlasInfo.extend = new Vector2(resolution.x / maxSize, resolution.y / maxSize);

            if(start.z >= maxDepth){
                throw new Error("The texture atlas is overflowing. Please reduce your textures or the resolution of your textures")
            }

            textures[start.z].push({
                x: start.x,
                y: start.y,
                depth: start.z,
                width: resolution.x,
                height: resolution.y,
                bitmap: material.diffuseTexture.bitmap,
                material,
            })
        }

        console.log(textures);

        this.texturesContained = textures
    }

    makeWorldTexture(resolution){
        this.worldTextureResolution = resolution;
        
        this.worldTexture = this.device.createTexture({
            dimension: "2d",
            format: "rgba16float", // might decrease later
            label: "Browzium Engine Texture Atlas",
            mipLevelCount: 1, // will increase later
            sampleCount: 1, // idk what this is
            size: { width: resolution.x, height: resolution.y, depthOrArrayLayers: 1 },
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
        })

        this.worldTextureSampler = this.device.createSampler({
            addressModeU: "clamp-to-edge",
            addressModeV: "clamp-to-edge",
            addressModeW: "clamp-to-edge",
            label: "Browzium Engine Texture Atlas Sampler",

            magFilter: "linear", // Will be user costumizable
            minFilter: "linear", // Will be user costumizable
            mipmapFilter: "nearest", // Will be user costumizable
        })
    }

    applyWorldTexture(texture){
        if (
            texture instanceof ImageBitmap ||
            texture instanceof HTMLVideoElement ||
            texture instanceof VideoFrame ||
            texture instanceof HTMLCanvasElement ||
            texture instanceof OffscreenCanvas
        ) {
            this.device.queue.copyExternalImageToTexture(
                {
                    source: texture
                },
                {
                    mipLevel: 0,
                    texture: this.worldTexture
                },
                [
                    this.worldTextureResolution.x,
                    this.worldTextureResolution.y,
                    1                
                ]
            )
        } else {
            this.device.queue.writeTexture(
                {
                    mipLevel: 0,
                    texture: this.worldTexture
                },
                texture.data.buffer || texture.data,
                {
                    bytesPerRow: 4 * 2 * this.worldTextureResolution.x,
                    rowsPerImage: this.worldTextureResolution.y
                },
                [
                    this.worldTextureResolution.x,
                    this.worldTextureResolution.y,
                    1
                ]
            )
        }
    }

    #makeTextureAtlas() {
        //let limit2D = Math.floor(this.device.limits.maxTextureDimension2D / 2)
        //let limit3D = this.device.limits.maxTextureArrayLayers

        let limit2D = 4096

        this.textureAtlas = this.device.createTexture({
            dimension: "2d",
            format: "rgba16float", // might decrease later
            label: "Browzium Engine Texture Atlas",
            mipLevelCount: 1, // will increase later
            sampleCount: 1, // idk what this is
            size: { width: limit2D, height: limit2D, depthOrArrayLayers: Math.max(this.texturesContained.length, 2) },
            usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.RENDER_ATTACHMENT,
        })

        this.textureAtlasSampler = this.device.createSampler({
            addressModeU: "clamp-to-edge",
            addressModeV: "clamp-to-edge",
            addressModeW: "clamp-to-edge",
            label: "Browzium Engine Texture Atlas Sampler",

            magFilter: "linear", // Will be user costumizable
            minFilter: "linear", // Will be user costumizable
            mipmapFilter: "nearest", // Will be user costumizable
        })
    }

    #applyTextureAtlas() {
        for (let atlasDepthIndex = 0; atlasDepthIndex < this.texturesContained.length; atlasDepthIndex++) {
            let atlasDepth = this.texturesContained[atlasDepthIndex];

            for (let textureIndex = 0; textureIndex < atlasDepth.length; textureIndex++) {
                let texture = atlasDepth[textureIndex]

                if (
                    texture.bitmap instanceof ImageBitmap ||
                    texture.bitmap instanceof HTMLVideoElement ||
                    texture.bitmap instanceof VideoFrame ||
                    texture.bitmap instanceof HTMLCanvasElement ||
                    texture.bitmap instanceof OffscreenCanvas
                ) {
                    this.device.queue.copyExternalImageToTexture(
                        {
                            origin: [0, 0],
                            source: texture.bitmap
                        },
                        {
                            mipLevel: 0,
                            origin: [texture.x, texture.y],
                            texture: this.textureAtlas
                        },
                        [
                            texture.width,
                            texture.height,
                            atlasDepthIndex + 1
                        ]
                    )
                } else {
                    this.device.queue.writeTexture(
                        {
                            mipLevel: 0,
                            origin: [texture.x, texture.y],
                            texture: this.textureAtlas
                        },
                        texture.bitmap.buffer || texture.bitmap,
                        {
                            bytesPerRow: 4 * 2 * texture.width,
                            rowsPerImage: texture.height
                        },
                        [
                            texture.width,
                            texture.height,
                            atlasDepthIndex + 1
                        ]
                    )
                }
            }
        }
    }

    async generateImage() {

        // Run the compute shader

        const commandEncoder = this.device.createCommandEncoder();

        const passEncoder = commandEncoder.beginComputePass();

        passEncoder.setPipeline(this.computePipeline);

        passEncoder.setBindGroup(0, this.computeDataBindGroup);
        passEncoder.setBindGroup(1, this.computeMapBindGroup);
        passEncoder.setBindGroup(2, this.computeImageBindGroup);
        passEncoder.setBindGroup(3, this.renderHistoryDataBindGroup);

        passEncoder.dispatchWorkgroups(Math.ceil(this.canvas.width / 16), Math.ceil(this.canvas.height / 16), 1); //  Z for SPP
        passEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone()
    }

    async readImage() {
        const copyCommandEncoder = this.device.createCommandEncoder();
        copyCommandEncoder.copyBufferToBuffer(this.renderTextureColor, 0, this.renderReadTexture, 0, this.renderReadTexture.size);
        this.device.queue.submit([copyCommandEncoder.finish()]);
        await this.device.queue.onSubmittedWorkDone();

        await this.renderReadTexture.mapAsync(GPUMapMode.READ);

        const arrayBuffer = this.renderReadTexture.getMappedRange();
        const data = new Float32Array(new Float32Array(arrayBuffer));

        this.renderReadTexture.unmap();

        return data
    }

    async renderImage() {
        // Copy the history buffer

        const copyEncoder = this.device.createCommandEncoder();

        copyEncoder.copyTextureToTexture(
            {
                texture: this.renderTextureHistory,
            },
            {
                texture: this.renderTextureHistoryRead,
            },
            {
                width: this.canvas.width,
                height: this.canvas.height,
                depthOrArrayLayers: 1,
            },
        );

        this.device.queue.submit([copyEncoder.finish()]);

        // Write image to screen

        const commandEncoder = this.device.createCommandEncoder();
        const currentTexture = this.context.getCurrentTexture();

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

        this.device.queue.submit([commandEncoder.finish()]);
    }

    UpdateData() {
        let computeGlobalData = new Float32Array([
            this.canvas.width,
            this.canvas.height,

            this.Camera.FieldOfView,
            //this.rpp,
            //this.bounces,
            this.focalLength,

            this.Camera.Position.x,
            this.Camera.Position.y,
            this.Camera.Position.z,
            this.apertureSize,

            ...this.Camera.CameraToWorldMatrix.getContents(),

            this.tonemapMode,
            this.gammaCorrect,
            //0,
            //0
        ])

        this.Camera.wasCameraUpdated = false;
        this.UpdateDataBuffer = false;
        this.device.queue.writeBuffer(this.computeGlobalData, 0, computeGlobalData, 0, computeGlobalData.length);
    }

    UpdateRenderData() {
        let renderData = new Float32Array([
            this.staticFrames,
            this.frame
        ])

        this.device.queue.writeBuffer(this.renderHistoryData, 0, renderData, 0, renderData.length);
    }

    SetMaterials(materialList, updateBuffer) {
        this.materials = deepCopy(materialList);

        let oldSize = (this.computeMaterialData || { size: 0 }).size / 4
        let newSize = getNext2Power(Object.keys(this.materials).length) * materialStride

        while (newSize % 4 > 0) {
            newSize++;
        }

        let materialData = new Float32Array(newSize);

        if (newSize > oldSize) {
            this.computeMaterialData = this.device.createBuffer({
                size: materialData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (updateBuffer) {
                this.#makeBindGroups()
            }
        }

        let materialsKeys = Object.keys(this.materials)
        for (let matIndex = 0; matIndex < materialsKeys.length; matIndex++) {
            let material = this.materials[materialsKeys[matIndex]]
            let locationStart = materialStride * matIndex;

            // Diffuse

            materialData[locationStart + 0] = material.diffuse.x;
            materialData[locationStart + 1] = material.diffuse.y;
            materialData[locationStart + 2] = material.diffuse.z;
            materialData[locationStart + 3] = material.diffuseTexture.atlasInfo.depth;

            // Specular

            materialData[locationStart + 4] = material.specular.x;
            materialData[locationStart + 5] = material.specular.y;
            materialData[locationStart + 6] = material.specular.z;
            materialData[locationStart + 7] = material.transparency;

            // UV Mapping

            materialData[locationStart + 8] = material.diffuseTexture.atlasInfo.start.x;
            materialData[locationStart + 9] = material.diffuseTexture.atlasInfo.start.y;
            materialData[locationStart + 10] = material.diffuseTexture.atlasInfo.extend.x;
            materialData[locationStart + 11] = material.diffuseTexture.atlasInfo.extend.y;

            // Other stuff

            materialData[locationStart + 12] = material.index_of_refraction;
            materialData[locationStart + 13] = material.reflectance;
            materialData[locationStart + 14] = material.emittance;
            materialData[locationStart + 15] = material.roughtness;
        }

        console.log("Material data: ", this.materials, materialData)

        this.device.queue.writeBuffer(this.computeMaterialData, 0, materialData, 0, materialData.length);
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

    #SetOctree(triangleArray, updateBuffer) {
        let octree = this.CreateOctree(triangleArray)

        let oldSize = (this.computeOctreeTreeData || { size: 0 }).size / 4
        let newSize = getNext2Power(octree.length) * octreeBranchStride

        let octreeData = new Float32Array(newSize);

        if (newSize > oldSize) {
            this.computeOctreeTreeData = this.device.createBuffer({
                size: octreeData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (updateBuffer) {
                this.#makeBindGroups()
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

        this.device.queue.writeBuffer(this.computeOctreeTreeData, 0, octreeData, 0, octreeData.length);
    }

    #SetLights(triangleArray) {
        let lightTriangleArray = triangleArray.slice().filter(t => this.materials[t.material].emittance > 0);

        let oldSize = (this.computeLightData || { size: 0 }).size / 4
        let newSize = getNext2Power(lightTriangleArray.length)

        let totalSize = 1 + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let triangleData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.computeLightData = this.device.createBuffer({
                size: triangleData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });
        }

        triangleData[0] = lightTriangleArray.length

        for (let triIndex = 0; triIndex < lightTriangleArray.length; triIndex++) {
            triangleData[triIndex + 1] = triangleArray.indexOf(lightTriangleArray[triIndex]);
        }

        this.device.queue.writeBuffer(this.computeLightData, 0, triangleData, 0, triangleData.length);
    }

    SetTriangles(triangleArray, updateOctree, updateTextures, updateBuffer) {
        triangleArray = triangleArray.map(deepCopy)
        this.#SetLights(triangleArray);

        if (updateTextures) {
            this.#computeAtlasFormat(triangleArray)
            this.#makeTextureAtlas()
            this.#applyTextureAtlas()

            this.SetMaterials(this.materials, true)
        }


        let startIndex = 4;

        let oldSize = (this.computeMapData || { size: 0 }).size / 4
        let newSize = getNext2Power(triangleArray.length) * triangleStride + startIndex

        let totalSize = startIndex + newSize

        while (totalSize % 4 > 0) {
            totalSize++;
        }

        let triangleData = new Float32Array(totalSize);

        if (totalSize > oldSize) {
            this.computeMapData = this.device.createBuffer({
                size: triangleData.byteLength,
                usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
            });

            if (updateBuffer) {
                this.#makeBindGroups()
            }
        }

        triangleData[0] = triangleArray.length
        triangleData[1] = 0
        triangleData[2] = 0
        triangleData[3] = 0

        let materialsKeys = Object.keys(this.materials)
        for (let triIndex = 0; triIndex < triangleArray.length; triIndex++) {
            let triangle = triangleArray[triIndex]
            let locationStart = triangleStride * triIndex + startIndex;

            // Vertices

            triangleData[locationStart + 0] = triangle.a.x;
            triangleData[locationStart + 1] = triangle.a.y;
            triangleData[locationStart + 2] = triangle.a.z;
            triangleData[locationStart + 3] = materialsKeys.indexOf(triangle.material); // material index

            triangleData[locationStart + 4] = triangle.b.x;
            triangleData[locationStart + 5] = triangle.b.y;
            triangleData[locationStart + 6] = triangle.b.z;
            triangleData[locationStart + 7] = triangle.objectId; // object id

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

            // UVs

            triangleData[locationStart + 24] = triangle.uva.x;
            triangleData[locationStart + 25] = triangle.uva.y;
            triangleData[locationStart + 26] = triangle.uvb.x;
            triangleData[locationStart + 27] = triangle.uvb.y;

            triangleData[locationStart + 28] = triangle.uvc.x;
            triangleData[locationStart + 29] = triangle.uvc.y;
            triangleData[locationStart + 30] = 0;
            triangleData[locationStart + 31] = 0;
        }

        this.device.queue.writeBuffer(this.computeMapData, 0, triangleData, 0, triangleData.length);

        if (updateOctree) {
            this.#SetOctree(triangleArray, true)
        }
    }

    async RenderFrame(readImage) {
        this.frame++;
        this.staticFrames++;

        if (this.canvas.width !== this.#lastCanvasSize.width || this.canvas.height !== this.#lastCanvasSize.height) {
            this.#lastCanvasSize = { width: this.canvas.width, height: this.canvas.height }


            for (const denoiserName in this.denoisersBuilt) {
                if (this.denoisersBuilt.hasOwnProperty(denoiserName)) {
                    this.denoisersBuilt[denoiserName].makeBindGroups()
                }
            }

            this.#makeBindGroups()
            this.UpdateDataBuffer = true;
        }

        if (this.Camera.wasCameraUpdated) {
            this.staticFrames = 0;
        }

        if (this.Camera.wasCameraUpdated || this.UpdateDataBuffer) {
            this.UpdateData();
        }

        this.UpdateRenderData()

        await this.generateImage();

        // denoise

        if (!this.denoisersBuilt[this.denoiser]) {
            throw new Error(`${this.denoiser} is not a available denoiser.`)
        }

        await this.denoisersBuilt[this.denoiser].denoise()

        // render

        await this.renderImage();

        if (readImage) {
            return { image: this.readImage() }
        }
    }

    async Init() {
        this.context = this.canvas.getContext('webgpu');
        this.adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
        if (!this.adapter) {
            throw Error("Couldn't request WebGPU adapter.");
        }

        if (!this.adapter.features.has("float32-filterable")) {
            throw new Error("Filterable 32-bit float textures support is not available");
        }

        this.device = await this.adapter.requestDevice({
            label: "Browzium GPU Device",
            requiredFeatures: [
                "float32-filterable"
            ],
            requiredLimits: {
                maxStorageTexturesPerShaderStage: 6,
            }
        });

        this.presentationFormat = await navigator.gpu.getPreferredCanvasFormat();

        await this.context.configure({
            device: this.device,
            format: this.presentationFormat,
            alphaMode: "opaque",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        })

        this.frame = 0;
        this.staticFrames = 0;

        this.#computeAtlasFormat([])
        this.#makeTextureAtlas(1)

        this.makeWorldTexture(new Vector2(1, 1))

        this.#SetOctree([], false);
        this.SetMaterials([], false);
        this.SetTriangles([], false, true, false);
        this.#makePipelines();
        this.#makeBindGroups();

        this.loadDenoiser("none")

        //this.UpdateData();

        //await this.#Denoiser.Init()
    }
}

export default RenderingManager

function deepCopy(obj) {
    return obj;

    /*if (obj === null || typeof obj !== 'object') {
        return obj;
    }

    if (obj instanceof Date) {
        return new Date(obj.getTime());
    }

    if (obj instanceof Array) {
        return obj.map(deepCopy);
    }

    if (obj instanceof Uint8ClampedArray) {
        return new Uint8ClampedArray(obj);
    }

    if (obj instanceof Object) {
        const copiedObject = {};
        for (const key in obj) {
            if (obj.hasOwnProperty(key)) {
                copiedObject[key] = deepCopy(obj[key]);
            }
        }
        return copiedObject;
    }*/

    //return structuredClone(obj)
}
