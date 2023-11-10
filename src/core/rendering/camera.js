import Vector3 from "../classes/Vector3.js";
import Matrix from "../classes/Matrix.js";

const globalUpVector = new Vector3(0, 1, 0);

class CameraModel {
    Position = new Vector3(0, 0, 0);
    Orientation = new Vector3(0, 0, -1);
    CameraToWorldMatrix = new Matrix(4, 4);
    FieldOfView = 90;

    wasCameraUpdated;

    ComputeCameraToWorldMatrix() {
        let forward = this.Orientation.normalize();
        let right = forward.cross(globalUpVector).normalize();
        let up = right.cross(forward);

        this.CameraToWorldMatrix.set(0, 0, right.x); this.CameraToWorldMatrix.set(0, 1, right.y); this.CameraToWorldMatrix.set(0, 2, right.z); this.CameraToWorldMatrix.set(0, 3, 0);
        this.CameraToWorldMatrix.set(1, 0, up.x); this.CameraToWorldMatrix.set(1, 1, up.y); this.CameraToWorldMatrix.set(1, 2, up.z); this.CameraToWorldMatrix.set(1, 3, 0);
        this.CameraToWorldMatrix.set(2, 0, forward.x); this.CameraToWorldMatrix.set(2, 1, forward.y); this.CameraToWorldMatrix.set(2, 2, forward.z); this.CameraToWorldMatrix.set(2, 3, 0);
        this.CameraToWorldMatrix.set(3, 0, 0); this.CameraToWorldMatrix.set(3, 1, 0); this.CameraToWorldMatrix.set(3, 2, 0); this.CameraToWorldMatrix.set(3, 3, 1);
    }

    SetOrientation(Orientation) {
        this.Orientation = Orientation
        this.ComputeCameraToWorldMatrix()
        this.wasCameraUpdated = true
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