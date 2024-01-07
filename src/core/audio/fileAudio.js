/*
Header (44 bytes):
4 bytes: "RIFF" (chunk identifier)
4 bytes: File size (44 + size of data chunk, little-endian)
4 bytes: "WAVE" (file format)
4 bytes: "fmt " (format subchunk identifier)
4 bytes: Subchunk size (16 for PCM)
2 bytes: Audio format (1 for PCM)
2 bytes: Number of channels (1 for mono, 2 for stereo, etc.)
4 bytes: Sample rate (e.g., 44100 Hz)
4 bytes: Byte rate (SampleRate * NumChannels * BitsPerSample/8)
2 bytes: Block align (NumChannels * BitsPerSample/8)
2 bytes: Bits per sample (e.g., 16 bits)
4 bytes: "data" (data subchunk identifier)
4 bytes: Size of the data (size of sound data)
*/

let defaultChannels = [
    {},
    {},
    {}
]

class fileAudioManager {
    channels = []
    opts = {}

    //audioStream;
    audioBuffer;
    #audioIntermediaryArray;

    constructor(opts = {}) {
        opts = {
            channels: structuredClone(defaultChannels),
            sampleRate: 48000,
            bitsPerSample: 16,

            ...opts,
        }

        opts.byteRate = opts.channels.length * opts.sampleRate * opts.bitsPerSample / 8
        opts.blockAlign = opts.channels.length * opts.bitsPerSample / 8
        this.channels = opts.channels
        this.opts = opts;

        //this.audioStream = new 
        this.clearBuffer(0);
    }

    clearBuffer(additionalSize = 0) {
        this.#audioIntermediaryArray = new Array(this.opts.sampleRate * 10)

        let audioBuffer = new DataView(new ArrayBuffer(44 + additionalSize * this.opts.channels.length * this.opts.bitsPerSample / 8))

        // Magic Identifier

        audioBuffer.setUint8(0, 'R'.charCodeAt(0));
        audioBuffer.setUint8(1, 'I'.charCodeAt(0));
        audioBuffer.setUint8(2, 'F'.charCodeAt(0));
        audioBuffer.setUint8(3, 'F'.charCodeAt(0));

        // File size

        audioBuffer.setUint32(4, 36 + additionalSize * additionalSize * this.opts.channels.length * this.opts.bitsPerSample / 8, true)

        // Magic identifier

        audioBuffer.setUint8(8, 'W'.charCodeAt(0));
        audioBuffer.setUint8(9, 'A'.charCodeAt(0));
        audioBuffer.setUint8(10, 'V'.charCodeAt(0));
        audioBuffer.setUint8(11, 'E'.charCodeAt(0));

        audioBuffer.setUint8(12, 'f'.charCodeAt(0));
        audioBuffer.setUint8(13, 'm'.charCodeAt(0));
        audioBuffer.setUint8(14, 't'.charCodeAt(0));
        audioBuffer.setUint8(15, ' '.charCodeAt(0));

        audioBuffer.setUint32(16, 16)
        audioBuffer.setUint16(20, 1)

        // Header information

        audioBuffer.setUint16(22, this.opts.channels.length)
        audioBuffer.setUint32(24, this.opts.sampleRate)
        audioBuffer.setUint32(28, this.opts.byteRate)
        audioBuffer.setUint16(32, this.opts.blockAlign)
        audioBuffer.setUint16(34, this.opts.bitsPerSample)

        audioBuffer.setUint8(36, 'd'.charCodeAt(0));
        audioBuffer.setUint8(37, 'a'.charCodeAt(0));
        audioBuffer.setUint8(38, 't'.charCodeAt(0));
        audioBuffer.setUint8(39, 'a'.charCodeAt(0));

        audioBuffer.setUint32(40, 0) // data size

        this.audioBuffer = audioBuffer
    }

    recalculateBuffer() {

    }
}

export default fileAudioManager