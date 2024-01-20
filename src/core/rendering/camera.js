import Vector3 from "../classes/Vector3.js";
import Matrix from "../classes/Matrix.js";
import Quaternion from "../classes/Quaternion.js";

const globalUpVector = new Vector3(0, 1, 0);

class CameraModel {
    Position = new Vector3(0, 0, 0);
    Orientation = new Quaternion(0, 0, 0, 1);
    CameraToWorldMatrix = new Matrix(4, 4);
    FieldOfView = 90;

    wasCameraUpdated = false;

    forward = new Vector3(0, 0, 0);
    right = new Vector3(0, 0, 0);
    up = new Vector3(0, 0, 0);

    ComputeCameraToWorldMatrix() {
        this.forward = this.Orientation.multiplyVector(new Vector3(0, 0, -1)).normalize();
        this.right = globalUpVector.cross(this.forward).normalize();
        this.up = this.forward.cross(this.right).normalize();

        this.CameraToWorldMatrix.set(0, 0, this.right.x);   this.CameraToWorldMatrix.set(0, 1, this.right.y);   this.CameraToWorldMatrix.set(0, 2, this.right.z);   this.CameraToWorldMatrix.set(0, 3, 0);
        this.CameraToWorldMatrix.set(1, 0, this.up.x);      this.CameraToWorldMatrix.set(1, 1, this.up.y);      this.CameraToWorldMatrix.set(1, 2, this.up.z);      this.CameraToWorldMatrix.set(1, 3, 0);
        this.CameraToWorldMatrix.set(2, 0, this.forward.x); this.CameraToWorldMatrix.set(2, 1, this.forward.y); this.CameraToWorldMatrix.set(2, 2, this.forward.z); this.CameraToWorldMatrix.set(2, 3, 0);
        this.CameraToWorldMatrix.set(3, 0, 0);              this.CameraToWorldMatrix.set(3, 1,      0);         this.CameraToWorldMatrix.set(3, 2, 0);              this.CameraToWorldMatrix.set(3, 3, 1);
    }

    SetOrientationMatrix(matrix){
        const rotationMatrix = new Matrix(3, 3, [
            matrix.get(0, 0), matrix.get(0, 1), matrix.get(0, 2),
            matrix.get(1, 0), matrix.get(1, 1), matrix.get(1, 2),
            matrix.get(2, 0), matrix.get(2, 1), matrix.get(2, 2)
        ]);
    
        const translationVector = new Vector3(
            matrix.get(0, 3),
            matrix.get(1, 3),
            matrix.get(2, 3)
        );
    
        const trace = rotationMatrix.get(0, 0) + rotationMatrix.get(1, 1) + rotationMatrix.get(2, 2);
        let qx, qy, qz, qw;
    
        if (trace > 0) {
            const s = 0.5 / Math.sqrt(trace + 1.0);
            qw = 0.25 / s;
            qx = (rotationMatrix.get(2, 1) - rotationMatrix.get(1, 2)) * s;
            qy = (rotationMatrix.get(0, 2) - rotationMatrix.get(2, 0)) * s;
            qz = (rotationMatrix.get(1, 0) - rotationMatrix.get(0, 1)) * s;
        } else if (rotationMatrix.get(0, 0) > rotationMatrix.get(1, 1) && rotationMatrix.get(0, 0) > rotationMatrix.get(2, 2)) {
            const s = 2.0 * Math.sqrt(1.0 + rotationMatrix.get(0, 0) - rotationMatrix.get(1, 1) - rotationMatrix.get(2, 2));
            qw = (rotationMatrix.get(2, 1) - rotationMatrix.get(1, 2)) / s;
            qx = 0.25 * s;
            qy = (rotationMatrix.get(0, 1) + rotationMatrix.get(1, 0)) / s;
            qz = (rotationMatrix.get(0, 2) + rotationMatrix.get(2, 0)) / s;
        } else if (rotationMatrix.get(1, 1) > rotationMatrix.get(2, 2)) {
            const s = 2.0 * Math.sqrt(1.0 + rotationMatrix.get(1, 1) - rotationMatrix.get(0, 0) - rotationMatrix.get(2, 2));
            qw = (rotationMatrix.get(0, 2) - rotationMatrix.get(2, 0)) / s;
            qx = (rotationMatrix.get(0, 1) + rotationMatrix.get(1, 0)) / s;
            qy = 0.25 * s;
            qz = (rotationMatrix.get(1, 2) + rotationMatrix.get(2, 1)) / s;
        } else {
            const s = 2.0 * Math.sqrt(1.0 + rotationMatrix.get(2, 2) - rotationMatrix.get(0, 0) - rotationMatrix.get(1, 1));
            qw = (rotationMatrix.get(1, 0) - rotationMatrix.get(0, 1)) / s;
            qx = (rotationMatrix.get(0, 2) + rotationMatrix.get(2, 0)) / s;
            qy = (rotationMatrix.get(1, 2) + rotationMatrix.get(2, 1)) / s;
            qz = 0.25 * s;
        }
    
        const quaternion = new Quaternion(qx, qy, qz, qw).normalize();

        this.SetPosition(translationVector)
        this.SetOrientationQuaternion(quaternion);
    }

    NewOrientationMatrix(){
        this.CameraToWorldMatrix = new Matrix(4, 4);
    }

    UpdateCamera(){
        this.wasCameraUpdated = true;
    }

    SetOrientationQuaternion(Orientation) {
        this.Orientation = Orientation
        this.ComputeCameraToWorldMatrix()
        this.wasCameraUpdated = true
    }

    SetOrientationLookAt(Orientation) {
        this.Orientation = Orientation
        this.ComputeCameraToWorldMatrix()
        this.wasCameraUpdated = true
    }

    SetOrientationEuler(Orientation) {
        let pitch = (Orientation.x % 360) * (Math.PI / 180);
        let yaw = (Orientation.y % 360) * (Math.PI / 180);
        let roll = (Orientation.z % 360) * (Math.PI / 180);

        let c1 = Math.cos(yaw / 2);
        let s1 = Math.sin(yaw / 2);
        let c2 = Math.cos(pitch / 2);
        let s2 = Math.sin(pitch / 2);
        let c3 = Math.cos(roll / 2);
        let s3 = Math.sin(roll / 2);

        let orientation = new Quaternion(
            s1 * c2 * c3 + c1 * s2 * s3,
            c1 * s2 * c3 - s1 * c2 * s3,
            c1 * c2 * s3 - s1 * s2 * c3,
            c1 * c2 * c3 + s1 * s2 * s3
        );

        this.SetOrientationQuaternion(orientation);
    }

    GetOrientationEuler(){
        const { x, y, z, w } = this.Orientation;

        const sinP = 2.0 * (w * x + y * z);
        const cosP = 1.0 - 2.0 * (x * x + y * y);
        const pitch = Math.atan2(sinP, cosP);
    
        const sinY = 2.0 * (w * y - z * x);
        const cosY = 1.0 - 2.0 * (y * y + z * z);
        const yaw = Math.atan2(sinY, cosY);
    
        const sinR = 2.0 * (w * z + x * y);
        const cosR = 1.0 - 2.0 * (y * y + z * z);
        const roll = Math.atan2(sinR, cosR);
    
        return new Vector3(pitch * 180.0 / Math.PI, yaw * 180.0 / Math.PI, roll * 180.0 / Math.PI);
    }

    SetPosition(cameraPosition) {
        this.Position = cameraPosition
        this.ComputeCameraToWorldMatrix()
        this.wasCameraUpdated = true
    }

    SetFOV(FieldOfView) {
        this.FieldOfView = FieldOfView
        this.wasCameraUpdated = true
    }
}

export default CameraModel;