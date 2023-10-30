import AudioManager from "./core/audio/main.js";
import RenderingManager from "./core/rendering/main.js";

class Engine {
    AudioManager;
    RenderingManager;

    isActive;

    lastFrameTime = performance.now();
    lastStepTime = performance.now();

    constructor(opts = {}){
        opts = {
            audio: {

            },

            renderer: {
                shaders: {

                },
            },
            ...opts,
        }

        this.AudioManager = new AudioManager(opts.audio)
        this.RenderingManager = new RenderingManager(opts.renderer)
    }

    async InitActivation(){
        await this.AudioManager.Init()
        await this.RenderingManager.Init()
    }

    async RenderFrame(){
        let delta = performance.now() - this.lastFrameTime
        this.lastFrameTime = performance.now()

        //console.log(`frame render: ${delta}ms`)
        await this.RenderingManager.RenderFrame()
        
        return delta
    }

    async StepFrame(){
        let delta = performance.now() - this.lastStepTime
        this.lastStepTime = performance.now()

        //console.log(`frame step: ${delta}ms`)

        return delta
    }

    AwaitPageActivation(){
        return new Promise((resolve, reject) => {
            function onActivation(){
                resolve()

                document.removeEventListener("keydown", onActivation)
                document.removeEventListener("click", onActivation)
            }

            document.addEventListener('keydown', onActivation)
            document.addEventListener('click', onActivation)
        })
    }
}

export default Engine;