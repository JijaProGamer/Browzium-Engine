import Vector3 from "./Vector3.js";

class Triangle {
    a = new Vector3(0, 0, 0);
    b = new Vector3(0, 0, 0);
    c = new Vector3(0, 0, 0);

    na = new Vector3(0, 0, 0);
    nb = new Vector3(0, 0, 0);
    nc = new Vector3(0, 0, 0);

    t = new Vector3(0, 0, 0); // tangent

    material = "default";
    objectId = 0;

    getCentroid() {
        const centroid = new Vector3(
            (this.a.x + this.b.x + this.c.x) / 3,
            (this.a.y + this.b.y + this.c.y) / 3,
            (this.a.z + this.b.z + this.c.z) / 3
        );
        
        return centroid;
    }
}

export default Triangle;
export { Triangle }