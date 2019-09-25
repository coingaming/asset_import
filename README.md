# AssetImport

Webpack asset imports in Phoenix views/templates or LiveView's.

## Features
- Only load assets that are actually used for current render.
- Quarantees that nothing is over, under, double fetched.
- Optimal asset packaging and cacheability with webpack code spliting.
- Supports Phoenix LiveView's by loading assets dynamically.
- Mix dependencies that use `asset_import` are supported.

## Installation

The package can be installed by adding `auto_assets` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:asset_import, "~> 0.1.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/auto_assets](https://hexdocs.pm/auto_assets).

## Setup

#### 1. Config:

Typical `asset_import` config:
```elixir
# config/config.exs

config :asset_import,
  assets_base_url: "/assets",
  assets_path: File.cwd!() |> Path.join("assets"),
  manifest_path: File.cwd!() |> Path.join("priv/static/manifest.json"),
  entrypoints_path: File.cwd!() |> Path.join("assets/entrypoints.json")
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

#### 2. Create an assets module:

```elixir
defmodule MyAppWeb.Assets do
  use AssetImport,
    assets_path: "assets" # optional, defaults to "assets"
end
```

#### 3. Use assets module in your view module or `MyAppWeb.ex` `:view` helper:

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

#### 4. Add `render_scripts` and `render_styles` to your layout:

```html
<!--
  body, which is where most of your `asset_import` will be,
  needs to be called before `asset_styles` and `asset_scripts`
-->
<% body = render "body.html", assigns: assigns %>
<html>
  <head>
    ..
    <%= asset_styles() %>
  </head>
  <body>
    <%= body %>
    <%= asset_scripts() %>>
  </body>
</html>
```

#### 5. Setup assets: copy `example_assets/*` to your project assets folder.

Feel free to change files according to your project needs.

*The critical parts for `asset_import` to work are:*

1. `example_assets/package.json`:
  - dev dependency `webpack-manifest-plugin`
  - dependency `asset_import` (only needed when you use dynamic rendering in LiveView's)

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
34:    filename: '[id]-[contenthash].js',
35:    chunkFilename: '[id]-[contenthash].js',
36:    path: path.resolve(__dirname, '../priv/static/assets')
37:  },
38:  plugins: [
39:    new MiniCssExtractPlugin({
40:      filename: '[id]-[contenthash].css',
41:      chunkFilename: '[id]-[contenthash].css',
42:    }),
43:    new ManifestPlugin({ fileName: '../manifest.json' }),

..
```

#### 6. Optional: `import "asset_import"` to your main js.

Only needed when you use dynamic rendering in LiveView's.

## Usage

```css
/* assets/forms.css */

form {
  /* a lot of form styling, or import bootstrap `_forms.scss` etc */
}
```

```javascript
// assets/login_form.js

import "./forms.css"

// some login form specific javascript here
```

Anywhere in your views, templates, or LiveView renders:
```html
<div>
  <%= if @logged_in do %>
    <div>My profile..</div>
  <% else %>
    <%= asset_import "login_form" %>
    <form>Login form..</form>
  <% end %>
</div>
```

Assets `login_form.js` and `forms.css` are only loaded when user is not logged in.

