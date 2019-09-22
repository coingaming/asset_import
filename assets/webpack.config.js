const path = require('path');
const { ProvidePlugin } = require('webpack');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const ManifestPlugin = require('webpack-manifest-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const entrypoints = require('./entrypoints.json') || {};

if (Object.keys(entrypoints).length === 0) {
  console.log('No entrypoints');
  process.exit();
  return;
}

module.exports = (env, options) => ({
  optimization: {
    minimizer: [
      new UglifyJsPlugin({ cache: true, parallel: true, sourceMap: false }),
      new OptimizeCSSAssetsPlugin({})
    ],
    runtimeChunk: 'single',
    concatenateModules: true,
    splitChunks: {
      chunks: 'all',
      minChunks: 1,
      minSize: 0
    }
  },
  stats: {
    warnings: false
  },
  entry: entrypoints,
  output: {
    filename: options.mode === 'production' ? '[id]-[contenthash].js' : '[id].js',
    chunkFilename: options.mode === 'production' ? '[id]-[contenthash].js' : '[id].js',
    path: path.resolve(__dirname, '../priv/static/assets')
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.(scss|css)$/,
        use: [MiniCssExtractPlugin.loader, 'css-loader', 'sass-loader']
      },
      {
        test: /\.(png|jpg|gif)(\?v=\d+\.\d+\.\d+)?$/,
        loader: 'file-loader',
        options: {
          name: 'img/[name].[ext]'
        }
      },
      {
        test: /\.(eot|com|json|ttf|woff|woff2)(\?v=\d+\.\d+\.\d+)?$/,
        loader: 'file-loader',
        options: {
          name: 'fonts/[name].[ext]'
        }
      },
      {
        test: /\.svg(\?v=\d+\.\d+\.\d+)?$/,
        loader: 'file-loader',
        options: {
          name: 'svg/[name].[ext]'
        }
      }
    ]
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: options.mode === 'production' ? '[id]-[contenthash].css' : '[id].css',
      chunkFilename: options.mode === 'production' ? '[id]-[contenthash].css' : '[id].css',
    }),
    new CopyWebpackPlugin([{ from: 'static/', to: './' }]),
    new ManifestPlugin({ fileName: '../manifest.json' }),
    new CleanWebpackPlugin(),
    new ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
      Popper: ['popper.js', 'default']
    })
  ]
});
