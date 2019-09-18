defmodule AutoAssetsTest.Some do
  use AutoAssets.Assets

  def hello do
    import_assets("and")
    import_assets("some")
  end
end
