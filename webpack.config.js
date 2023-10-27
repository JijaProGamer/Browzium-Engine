const path = require('path');

const TerserPlugin = require("terser-webpack-plugin");

module.exports = {
  entry: './src/main.js',
  mode: "production",
  devtool: "source-map",
  optimization: {
    minimize: true,
    minimizer: [new TerserPlugin()],
  },
  experiments: {
    outputModule: true
  },
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
    library: {
        type: "module"
    }
  },
};
