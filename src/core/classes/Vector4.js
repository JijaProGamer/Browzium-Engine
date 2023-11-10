class Vector4 {
    x;
    y;
    z;
    w;

    constructor(x, y, z, w) {
        this.x = x || 0;
        this.y = y || 0;
        this.z = z || 0;
        this.w = w || 0;
    }

    set(x, y, z, w) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    copy() {
        return new Vector4(this.x, this.y, this.z, this.w);
    }

    add(vector) {
        this.x += vector.x;
        this.y += vector.y;
        this.z += vector.z;
        this.w += vector.w;
        return this;
    }

    subtract(vector) {
        this.x -= vector.x;
        this.y -= vector.y;
        this.z -= vector.z;
        this.w -= vector.w;
        return this;
    }

    multiplyScalar(scalar) {
        this.x *= scalar;
        this.y *= scalar;
        this.z *= scalar;
        this.w *= scalar;
        return this;
    }

    divideScalar(scalar) {
        if (scalar !== 0) {
            this.x /= scalar;
            this.y /= scalar;
            this.z /= scalar;
            this.w /= scalar;
        } else {
            throw new Error("Division by zero is not allowed.");
        }
        return this;
    }

    length() {
        return Math.sqrt(this.lengthSquared());
    }

    lengthSquared(){
        return this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w;
    }

    normalize() {
        const len = this.length();
        if (len !== 0) {
            this.x /= len;
            this.y /= len;
            this.z /= len;
            this.w /= len;
        }
        return this;
    }

    dot(vector) {
        return this.x * vector.x + this.y * vector.y + this.z * vector.z + this.w * vector.w;
    }

    static add(v1, v2) {
        return v1.copy().add(v2);
    }

    static subtract(v1, v2) {
        return v1.copy().subtract(v2);
    }

    static multiplyScalar(v, scalar) {
        return v.copy().multiplyScalar(scalar);
    }

    static divideScalar(v, scalar) {
        return v.copy().divideScalar(scalar);
    }
}

export default Vector4;
export { Vector4 };
