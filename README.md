# AssetImport

Webpack asset imports directly in Elixir code. For example in Phoenix controllers/views/templates or LiveView's.

## Features
- Only load assets that are actually used for current render.
- Quarantees that nothing is over, under, or double fetched.
- Optimal asset packaging and cacheability with webpack code splitting.
- Supports Phoenix LiveView's by loading assets dynamically.
- Supports mix dependencies that are using `asset_import`.

## Installation

The package can be installed by adding `asset_import` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:asset_import, "~> 0.1.0"}
  ]
end
```

## Usage

```css
/* assets/css/forms.css */

form {
  /* a lot of form styling, or import bootstrap `_forms.scss` etc */
}
```

```javascript
// assets/js/login_form.js

import "../css/forms.css"

// some login form specific javascript here
```

Anywhere in your views, templates, or LiveView renders:
```html
<div>
  <%= if @logged_in do %>
    <div>My profile..</div>
  <% else %>
    <%= asset_import "js/login_form" %>
    <form>Login form..</form>
  <% end %>
</div>
```

Assets `js/login_form.js` and `css/forms.css` are only loaded when user is not logged in.

## Setup

### 1. Add configuration

Typical `asset_import` config:
```elixir
# config/config.exs

config :asset_import,
  assets_base_url: "/",
  assets_path: Path.expand("assets"),
  manifest_path: Path.expand("priv/static/manifest.json"),
  entrypoints_path: Path.expand("assets/entrypoints.json")
```

Replace phoenix watcher from `webpack` to `nodemon`:
```elixir
# config/dev.exs

config :my_app, MyAppWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/nodemon/bin/nodemon.js", cd: Path.expand("../assets", __DIR__)]]
```
This is necessary for full webpack restart on `endpoints.json` change.

### 2. Create an assets module

```elixir
defmodule MyAppWeb.Assets do
  use AssetImport,
    assets_path: "assets" # optional, defaults to "assets"
end
```

### 3. Use your assets module in web module

```elixir
defmodule MyAppWeb do
  ..
  def view do
    quote do
      ..
      use MyAppWeb.Assets
      ..
    end
  end
  ..
end
```

### 4. Add scripts and styles to layout

Body, which is where most of your `asset_import` will be, needs to be called before `asset_styles` and `asset_scripts`.

```html
<% body = render "body.html", assigns %>
<html>
  <head>
    ..
    <%= asset_styles() %>
  </head>
  <body>
    <%= body %>
    <%= asset_scripts() %>
  </body>
</html>
```

If more control is needed over the tags then `asset_style_files` and `asset_script_files` can be used, which return a list of asset paths instead of html:
```html
<% body = render "body.html", assigns %>
<html>
  <head>
    ..
    <%= for path <- asset_style_files() do %>
      <link rel="stylesheet" href="<%= path %>" />
    <% end %>
  </head>
  <body>
    <%= body %>
    <%= for path <- asset_script_files() do %>
      <script type="text/javascript" src="<%= path %>"></script>
    <% end %>
  </body>
</html>
```

### 5. Add `AssetImport` hook to LiveView hooks (optional only for LiveView)

```javascript
import LiveSocket from "phoenix_live_view"
import Socket from "phoenix"
import AssetImport from "asset_import_hook"

let liveSocket = new LiveSocket("/live", Socket, { AssetImport })
liveSocket.connect()
```

### 6. Copy `example_assets/*` to your project assets folder

Feel free to change files according to your project needs.

*Critical places for `asset_import` are:*

1. `example_assets/package.json`:
  - dev dependency `webpack-manifest-plugin`, `nodemon`
  - dependency `asset_import_hook` (optional only for LiveView)

2. `example_assets/webpack.config.js`:
```javascript
..

 8: const entrypoints = require('./entrypoints.json') || {};
 9:
10: if (Object.keys(entrypoints).length === 0) {
11:   console.log('No entrypoints');
12:   process.exit();
13:   return;
14: }

..

23:    runtimeChunk: 'single',
24:    chunkIds: 'natural',
25:    concatenateModules: true,
26:    splitChunks: {
27:      chunks: 'all',
28:      minChunks: 1,
29:      minSize: 0
30:    }
31:  },
32:  entry: entrypoints,
33:  output: {
34:    filename: 'js/[id]-[contenthash].js',
35:    chunkFilename: 'js/[id]-[contenthash].js',
36:    path: path.resolve(__dirname, '../priv/static')
37:  },
38:  plugins: [
39:    new MiniCssExtractPlugin({
40:      filename: 'css/[id]-[contenthash].css',
41:      chunkFilename: 'css/[id]-[contenthash].css',
42:    }),
43:    new ManifestPlugin({ fileName: 'manifest.json' }),

..
```
