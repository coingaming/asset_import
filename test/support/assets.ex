defmodule AssetImport.Assets do
  use AssetImport,
    assets_path: "assets/",
    manifest_file: "priv/manifest.json"
end
