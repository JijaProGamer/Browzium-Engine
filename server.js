const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
    if (req.url.startsWith('/tfjs') || req.url.startsWith('/tfjs-backend-webgpu')) {
        // Handling requests for tfjs and tfjs-backend-webgpu modules
        const modulePath = path.join(__dirname, 'node_modules', req.url);
        serveFile(modulePath, res);
    } else {
        // Handling other requests
        const filePath = path.join(__dirname, mapInput(req.url));
        serveFile(filePath, res);
    }
});

function serveFile(filePath, res) {
    fs.readFile(filePath, (err, data) => {
        if (err) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('File not found');
        } else {
            const extname = path.extname(filePath);
            const contentType = getContentType(extname);

            res.writeHead(200, { 'Content-Type': contentType });

            res.end(data);
        }
    });
}

function mapInput(input) {
    let output = input;
    let inputParts = input.split("/");
    inputParts.shift();

    if (input === "/") {
        output = "/examples/including-the-module.html";
    }

    if (inputParts[0] === "maps") {
        output = `examples/${inputParts.join("/")}`;
    }

    return output;
}

function getContentType(ext) {
    switch (ext) {
        case '.html':
            return 'text/html';
        case '.css':
            return 'text/css';
        case '.js':
            return 'text/javascript';
        case '.png':
            return 'image/png';
        case '.jpg':
        case '.jpeg':
            return 'image/jpeg';
        default:
            return 'application/octet-stream';
    }
}

const PORT = 5500;

server.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});
