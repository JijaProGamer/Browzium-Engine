import Vector2 from "./Vector2";
import Vector3 from "./Vector3";
import Vector4 from "./Vector4";

function getVectorType(vector){
    if("w" in vector) return 4;
    if("z" in vector) return 3;
    if("y" in vector) return 2;

    return -1
}

function toVector(array){
    if(array.length == 4) {return new Vector4(...array)}
    if(array.length == 3) {return new Vector3(...array)}
    if(array.length == 2) {return new Vector2(...array)}
}

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

    multiply(matrix) {
        if (this.cols !== matrix.cols || this.rows !== matrix.cols) {
            throw new Error("Matrix dimensions are not compatible for multiplication.");
        }
    
        let result = new Matrix(this.rows, this.cols);
    
        for (let i = 0; i < this.rows; i++) {
            for (let j = 0; j < this.cols; j++) {

                let sum = 0;

                for (let k = 0; k < this.cols; k++) {
                    sum += this.get(i, k) * matrix.get(k, j);
                }

                result.set(i, j, sum);
            }
        }
    
        return result;
    }    

    multiplyVector(vector) {
        if (this.cols != getVectorType(vector) || this.rows != getVectorType(vector)) {
            throw new Error("Matrix and vector dimensions are not compatible for multiplication.");
        }

        let result = new Array(this.rows).fill(0);

        for (let i = 0; i < this.rows; i++) {
            for (let j = 0; j < this.cols; j++) {
                result[i] += this.get(i, j) * vector.get(j);
            }
        }

        return toVector(result);
    }

    inverse(){
        throw new Error("Matrix.inverse has not been made yet.")
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

    static rotationAxis(axis, angle) {
        let c = Math.cos(angle);
        let s = Math.sin(angle);
        let t = 1 - c;
    
        let x = axis.x, y = axis.y, z = axis.z;
    
        let rotationMatrix = new Matrix(3, 3, [
            t * x * x + c,     t * x * y - s * z, t * x * z + s * y,
            t * x * y + s * z, t * y * y + c,     t * y * z - s * x,
            t * x * z - s * y, t * y * z + s * x, t * z * z + c
        ]);
    
        return rotationMatrix;
    }
}

export default Matrix;
export { Matrix };