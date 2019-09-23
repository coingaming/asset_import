defmodule AssetImportTest.Some do
  use AssetImportTest.Assets

  def hello do
    asset_import("and")
    asset_import("some")
  end
end
