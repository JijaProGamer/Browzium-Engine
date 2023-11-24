import Vector3 from "./Vector3.js";

class Triangle {
    a = new Vector3(0, 0, 0);
    b = new Vector3(0, 0, 0);
    c = new Vector3(0, 0, 0);

    na = new Vector3(0, 0, 0);
    nb = new Vector3(0, 0, 0);
    nc = new Vector3(0, 0, 0);

    material = "default"
}

export default Triangle;
export { Triangle }