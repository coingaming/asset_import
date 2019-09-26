import Config

config :asset_import,
  assets_base_url: "/assets",
  assets_path: Path.expand("assets"),
  manifest_path: Path.expand("priv/static/manifest.json"),
  entrypoints_path: Path.expand("assets/entrypoints.json")

config :phoenix,
  json_library: Jason,
  template_engines: [leex: Phoenix.LiveView.Engine]

import_config "#{Mix.env()}.exs"
