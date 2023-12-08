import Vector3 from "./Vector3";

class Quaternion {
    x = 0;
    y = 0;
    z = 0;
    w = 1;

    constructor(x = 0, y = 0, z = 0, w = 1) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    normalize() {
        let length = Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w);
        if (length === 0) {
            this.x = 0;
            this.y = 0;
            this.z = 0;
            this.w = 1;
        } else {
            let invLength = 1 / length;
            this.x *= invLength;
            this.y *= invLength;
            this.z *= invLength;
            this.w *= invLength;
        }
        return this;
    }

    multiply(q) {
        let qx = this.w * q.x + this.x * q.w + this.y * q.z - this.z * q.y;
        let qy = this.w * q.y - this.x * q.z + this.y * q.w + this.z * q.x;
        let qz = this.w * q.z + this.x * q.y - this.y * q.x + this.z * q.w;
        let qw = this.w * q.w - this.x * q.x - this.y * q.y - this.z * q.z;

        return new Quaternion(qx, qy, qz, qw);
    }

    multiplyVector(v) {
        let ix = this.w * v.x + this.y * v.z - this.z * v.y;
        let iy = this.w * v.y + this.z * v.x - this.x * v.z;
        let iz = this.w * v.z + this.x * v.y - this.y * v.x;
        let iw = -this.x * v.x - this.y * v.y - this.z * v.z;

        return new Vector3(
            ix * this.w + iw * -this.x + iy * -this.z - iz * -this.y,
            iy * this.w + iw * -this.y + iz * -this.x - ix * -this.z,
            iz * this.w + iw * -this.z + ix * -this.y - iy * -this.x
        );
    }
}

export default Quaternion;