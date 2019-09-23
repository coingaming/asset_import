defmodule AssetImportTest.LayoutView do
  use Phoenix.View, root: ""

  def render("app.html", assigns) do
    ["LAYOUT", render(assigns.view_module, assigns.view_template, assigns)]
  end
end

defmodule AssetImportTest.AlternativeLayout do
  use Phoenix.View, root: ""

  def render("layout.html", assigns) do
    ["ALTERNATIVE", render(assigns.view_module, assigns.view_template, assigns)]
  end
end
