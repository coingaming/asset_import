import Config

config :asset_import,
  assets_path: File.cwd!() |> Path.join("assets"),
  manifest_path: File.cwd!() |> Path.join("priv/static/manifest.json"),
  entrypoints_path: File.cwd!() |> Path.join("assets/entrypoints.json")

config :phoenix,
  json_library: Jason,
  template_engines: [leex: Phoenix.LiveView.Engine]
