class AudioManager {
    audioContext;

    constructor(opts = {}) {

    }

    async Init() {
        this.audioContext = new (AudioContext || webkitAudioContext)()
        console.log(this.audioContext.destination)
    }

    CreateAudioBuffer(numSamples, numChannels = 1){
        if(typeof(numChannels) == "string"){
            numChannels = numChannels.split(".").reduce((a, b) => a + parseInt(b), 0)
        }

        return this.audioContext.createBuffer(numChannels, numSamples, this.audioContext.sampleRate);
    }

    PlaySoundInSpace(){

    }

    PlaySound(audioBuffer, pannerPosition=[0, 0, 0], pannerLookDirection=[0, 0, 0]) {
        const panner = this.audioContext.createPanner();
        const source = this.audioContext.createBufferSource();
        source.buffer = audioBuffer;

        panner.setPosition(pannerPosition[0], pannerPosition[1], pannerPosition[2]);
        panner.setOrientation(pannerLookDirection[0], pannerLookDirection[1], pannerLookDirection[2]);

        source.connect(this.audioContext.destination);
        panner.connect(this.audioContext.destination);

        source.start();

        source.onended = () => {
            source.stop();
            source.disconnect();
            panner.disconnect();
            source.onended = null;
        };
    }
}

export default AudioManager