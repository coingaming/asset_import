defmodule AssetImport.Other do
  use AssetImportTest.Assets

  def hello do
    asset_import("other")
    asset_import("module")
  end
end
