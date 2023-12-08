class Vector3 {
    x;
    y;
    z;

    constructor(x, y, z) {
        this.x = x || 0;
        this.y = y || 0;
        this.z = z || 0;
    }

    set(x, y, z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    get(position){
        if(position == 0) return this.x;
        if(position == 1) return this.y;
        if(position == 2) return this.z;
    }

    copy() {
        return new Vector3(this.x, this.y, this.z);
    }

    add(vector) {
        this.x += vector.x;
        this.y += vector.y;
        this.z += vector.z;
        return this;
    }

    subtract(vector) {
        this.x -= vector.x;
        this.y -= vector.y;
        this.z -= vector.z;
        return this;
    }

    multiplyScalar(scalar) {
        this.x *= scalar;
        this.y *= scalar;
        this.z *= scalar;
        return this;
    }

    divideScalar(scalar) {
        if (scalar !== 0) {
            this.x /= scalar;
            this.y /= scalar;
            this.z /= scalar;
        } else {
            throw new Error("Division by zero is not allowed.");
        }
        return this;
    }

    length() {
        return Math.sqrt(this.lengthSquared());
    }

    lengthSquared(){
        return this.x * this.x + this.y * this.y + this.z * this.z;
    }

    normalize() {
        const len = this.length();
        if (len !== 0) {
            this.x /= len;
            this.y /= len;
            this.z /= len;
        }
        return this;
    }

    dot(vector) {
        return this.x * vector.x + this.y * vector.y + this.z * vector.z;
    }

    cross(vector) {
        const x = this.y * vector.z - this.z * vector.y;
        const y = this.z * vector.x - this.x * vector.z;
        const z = this.x * vector.y - this.y * vector.x;
        return new Vector3(x, y, z);
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

export default Vector3;
export { Vector3 };