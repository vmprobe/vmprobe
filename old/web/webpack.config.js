require('es6-promise').polyfill(); // https://github.com/webpack/css-loader/issues/144

var path = require('path');
var webpack = require('webpack');

module.exports = {
  entry: [
    './src/index'
  ],
  output: {
    path: path.join(__dirname, 'dist'),
    filename: 'bundle.js',
    publicPath: '/static/'
  },
  module: {
    loaders: [
      {
        test: /\.js$/,
        loaders: ['babel'],
        include: path.join(__dirname, 'src')
      },
      {
        test: /\.css$/,
        loader: "style-loader!css-loader",
        include: path.join(__dirname, 'css'),
      },
      { test: /\.woff(2)?(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: "url-loader?limit=10000&minetype=application/font-woff" },
      { test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: "file-loader" },
    ]
  }
};


if (GLOBAL.WEBPACK_DEV_MODE) {
  console.log("Running webpack with dev config");

  module.exports.devtool = 'eval';

  module.exports.entry.unshift(
    'webpack-dev-server/client?http://' + GLOBAL.WEBPACK_DEV_HOST + ':' + GLOBAL.WEBPACK_DEV_PORT,
    'webpack/hot/only-dev-server'
  );

  module.exports.plugins = [
    new webpack.HotModuleReplacementPlugin()
  ],

  module.exports.module.loaders[0].loaders.unshift('react-hot');
}
