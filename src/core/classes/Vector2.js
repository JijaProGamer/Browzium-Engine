class Vector2 {
    x;
    y;

    constructor(x, y) {
        this.x = x || 0;
        this.y = y || 0;
    }

    set(x, y) {
        this.x = x;
        this.y = y;
    }

    copy() {
        return new Vector2(this.x, this.y);
    }

    add(vector) {
        this.x += vector.x;
        this.y += vector.y;
        return this;
    }

    subtract(vector) {
        this.x -= vector.x;
        this.y -= vector.y;
        return this;
    }

    multiplyScalar(scalar) {
        this.x *= scalar;
        this.y *= scalar;
        return this;
    }

    divideScalar(scalar) {
        if (scalar !== 0) {
            this.x /= scalar;
            this.y /= scalar;
        } else {
            throw new Error("Division by zero is not allowed.");
        }
        return this;
    }

    length() {
        return Math.sqrt(this.lengthSquared());
    }

    lengthSquared() {
        return this.x * this.x + this.y * this.y;
    }

    normalize() {
        const len = this.length();
        if (len !== 0) {
            this.x /= len;
            this.y /= len;
        }
        return this;
    }

    dot(vector) {
        return this.x * vector.x + this.y * vector.y;
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

export default Vector2
export { Vector2 }