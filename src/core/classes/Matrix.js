class Matrix {
    rows;
    cols;
    data;

    constructor(rows, cols, data) {
        this.rows = rows || 3;
        this.cols = cols || 3;
        this.data = data || [];

        if (this.data.length !== this.rows * this.cols) {
            this.data = new Array(this.rows * this.cols).fill(0);
        }
    }

    set(row, col, value) {
        if (row >= 0 && row < this.rows && col >= 0 && col < this.cols) {
            this.data[row * this.cols + col] = value;
        } else {
            throw new Error("Index out of bounds.");
        }
    }

    get(row, col) {
        if (row >= 0 && row < this.rows && col >= 0 && col < this.cols) {
            return this.data[row * this.cols + col];
        } else {
            throw new Error("Index out of bounds.");
        }
    }

    getContents(){
        return this.data;
    }

    copy() {
        return new Matrix(this.rows, this.cols, this.data.slice());
    }

    add(matrix) {
        if (this.rows === matrix.rows && this.cols === matrix.cols) {
            for (let i = 0; i < this.data.length; i++) {
                this.data[i] += matrix.data[i];
            }
        } else {
            throw new Error("Matrix dimensions must match for addition.");
        }
        return this;
    }

    subtract(matrix) {
        if (this.rows === matrix.rows && this.cols === matrix.cols) {
            for (let i = 0; i < this.data.length; i++) {
                this.data[i] -= matrix.data[i];
            }
        } else {
            throw Error("Matrix dimensions must match for subtraction.");
        }
        return this;
    }

    multiplyScalar(scalar) {
        for (let i = 0; i < this.data.length; i++) {
            this.data[i] *= scalar;
        }
        return this;
    }

    divideScalar(scalar) {
        for (let i = 0; i < this.data.length; i++) {
            this.data[i] /= scalar;
        }
        return this;
    }

    inverse(){
        throw new Error("Inverse not made yet.")
    }

    static add(m1, m2) {
        return m1.copy().add(m2);
    }

    static subtract(m1, m2) {
        return m1.copy().subtract(m2);
    }

    static multiplyScalar(matrix, scalar) {
        return matrix.copy().multiplyScalar(scalar);
    }
}

export default Matrix;
export { Matrix };