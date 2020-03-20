# AssetImport

Webpack asset imports directly in Elixir code. For example in Phoenix controllers/views/templates or LiveView's.

## Features
- Only load assets that are used for current render.
- Helps to avoid assets over, under, or double fetching.
- Optimal asset packaging and cache reuse with Webpack code splitting.
- Supports Phoenix LiveView's by loading assets dynamically.
- Supports mix dependencies that are using `asset_import`.

## Installation

The package can be installed by adding `asset_import` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:asset_import, "~> 0.4.10"}
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
    <!--
    You can use <% asset_import @conn, "js/login_form" %> (without =),
    if you are not using this template in LiveView. It will save some bytes from your html.
    -->
    <%= asset_import @conn, "js/login_form" %>
    <!--
    Inside LiveView use @socket instead @conn
    -->
    <%= asset_import @socket, "js/login_form" %>
    <form>Login form..</form>
  <% end %>
</div>
```

Usage with LiveView hooks that guarantees that code is always loaded before hook usage:
```html
<div>
  <%= if @logged_in do %>
    <div>My profile..</div>
  <% else %>
    <form data-hook="MyHook" phx-hook="AssetHook" data-assets="<%= asset_hook(@socket, "js/myHook") %>">
      Login form..
    </form>
  <% end %>
</div>
```

Assets `js/login_form.js` and `css/forms.css` are only loaded when user is not logged in.

## Setup

### 1. Configuration

Typical `asset_import` config:
```elixir
# config/config.exs

config :asset_import, MyAppWeb.Assets,
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

Disable entrypoints file generation in test.
```elixir
# config/test.exs

config :asset_import, entrypoints_path: :disabled
```

### 2. Create an assets module

```elixir
defmodule MyAppWeb.Assets do
  use AssetImport,
    assets_path: "assets" # optional, defaults to "assets"
  use AwesomeUiComponents.Assets # add dependency assets
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

### 4. Import file macros to your layout view

```elixir
defmodule MyAppWeb.LayoutView do
  use MyAppWeb, :view
  import MyAppWeb.Assets.Files
end
```

### 5. Add scripts and styles to layout

```html
<!-- Content rendering has to execute before scripts and styles -->
<% body = render "body.html", assigns %>

<html>
  <head>
    
    <!-- Styles for current page (render blocking) -->
    <%= asset_styles() %>

    <!-- Optional: Preload unused styles and scripts -->
    <%= preload_asset_styles() %>
    <%= preload_asset_scripts() %>

  </head>
  <body>
    <%= body %>

    <!-- Scripts for current page -->
    <%= asset_scripts() %>

  </body>
</html>
```

Or
```html
<!-- Content rendering has to execute before scripts and styles -->
<% body = render "body.html", assigns %>

<html>
  <head>
    

    <!-- Styles for current page (render blocking) -->
    <%= for path <- asset_style_files() do %>
      <link rel="stylesheet" href="<%= path %>" />
    <% end %>

    <!-- Optional: Preload unused styles and scripts -->
    <%= for path <- unused_asset_style_files() do %>
      <link rel="preload" href="<%= path %>" as="style">
    <% end %>
    <%= for path <- unused_asset_script_files() do %>
      <link rel="preload" href="<%= path %>" as="script">
    <% end %>

  </head>
  <body>
    <%= body %>

    <!-- Scripts for current page -->
    <%= for path <- asset_script_files() do %>
      <script type="text/javascript" src="<%= path %>"></script>
    <% end %>

  </body>
</html>
```

### 6. Add LiveView hook (only when LiveView is used)

```javascript
import LiveSocket from "phoenix_live_view"
import Socket from "phoenix"
import AssetImport from "asset_import_hook"

let liveSocket = new LiveSocket("/live", Socket, { AssetImport })
liveSocket.connect()
```

### 7. Webpack setup

Copy `example_assets/*` to your project assets or adjust existing files manually:

- ```javascript
  // assets/nodemon.json
  {
    "watch": ["entrypoints.json", "webpack.config.js"],
    "exec": "node_modules/webpack/bin/webpack.js --color --mode development --watch-stdin"
  }
  ```

- ```javascript
  // assets/package.json
  {
    ..
    "dependencies": {
      ..
      "asset_import_hook": "0.4.10" // only when LiveView is used
      ..
    },
    "devDependencies": {
      ..
      "nodemon": "1.19.2",
      "uglifyjs-webpack-plugin": "2.2.0",
      ..
    }
  }
  ```

- ```javascript
  // assets/webpack.config.js
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
