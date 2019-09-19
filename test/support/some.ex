defmodule AssetImportTest.Some do
  use AssetImport.Assets

  def hello do
    asset_import("and")
    asset_import("some")
  end
end
