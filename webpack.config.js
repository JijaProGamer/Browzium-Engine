const path = require('path');

module.exports = {
  entry: './src/main.js',
  output: {
    filename: 'bundle.js',  // Output bundle name
    path: path.resolve(__dirname, 'dist'),  // Output directory
  },
};
