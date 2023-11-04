import AudioManager from "./core/audio/main.js";
import RenderingManager from "./core/rendering/main.js";

class Engine {
    AudioManager;
    RenderingManager;

    isActive;

    constructor(opts = {}){
        opts = {
            audio: {

            },

            renderer: {
                shaders: {

                },
                fov: 90,
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
        let startTime = performance.now()

        await this.RenderingManager.RenderFrame()

        let delta = performance.now() - startTime
        
        return delta
    }

    async StepFrame(){
        let startTime = performance.now()
        


        let delta = performance.now() - startTime

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