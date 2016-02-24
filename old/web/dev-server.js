GLOBAL.WEBPACK_DEV_MODE = 1;
GLOBAL.WEBPACK_DEV_HOST = process.argv[2] || 'localhost';
GLOBAL.WEBPACK_DEV_PORT = process.argv[3] || 3000;

var webpack = require('webpack');
var WebpackDevServer = require('webpack-dev-server');

var config = require('./webpack.config.js');

process.stdin.on('data', function(data) { });
process.stdin.on('end', function() { process.exit(); });

new WebpackDevServer(webpack(config), {
  publicPath: config.output.publicPath,
  hot: true,
  historyApiFallback: true
}).listen(GLOBAL.WEBPACK_DEV_PORT, GLOBAL.WEBPACK_DEV_HOST, function (err, result) {
  if (err) {
    console.log(err);
  }

  if (GLOBAL.WEBPACK_DEV_PORT != 58118) {
    // 58118 is the port used by the perl dev mode launcher: don't print the listening line
    // in this case since perl prints its own listening line and we don't want to confuse users.
    console.log('react hot-loader listening at ' + GLOBAL.WEBPACK_DEV_HOST + ':' + GLOBAL.WEBPACK_DEV_PORT);
  }
});
