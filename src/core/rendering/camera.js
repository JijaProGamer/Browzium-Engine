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

    ComputeCameraToWorldMatrix() {
        let forward = this.Orientation.multiplyVector(new Vector3(0, 0, -1)).normalize();
        let right = globalUpVector.cross(forward).normalize();
        let up = forward.cross(right).normalize();

        this.CameraToWorldMatrix.set(0, 0, right.x);   this.CameraToWorldMatrix.set(0, 1, right.y);   this.CameraToWorldMatrix.set(0, 2, right.z);   this.CameraToWorldMatrix.set(0, 3, 0);
        this.CameraToWorldMatrix.set(1, 0, up.x);      this.CameraToWorldMatrix.set(1, 1, up.y);      this.CameraToWorldMatrix.set(1, 2, up.z);      this.CameraToWorldMatrix.set(1, 3, 0);
        this.CameraToWorldMatrix.set(2, 0, forward.x); this.CameraToWorldMatrix.set(2, 1, forward.y); this.CameraToWorldMatrix.set(2, 2, forward.z); this.CameraToWorldMatrix.set(2, 3, 0);
        this.CameraToWorldMatrix.set(3, 0, 0);         this.CameraToWorldMatrix.set(3, 1, 0);         this.CameraToWorldMatrix.set(3, 2, 0);         this.CameraToWorldMatrix.set(3, 3, 1);
    }

    SetOrientationMatrix(matrix){
        this.CameraToWorldMatrix = matrix;
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