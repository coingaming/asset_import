defmodule AssetImportTest do
  use ExUnit.Case
  use AssetImportTest.Assets
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  # alias Phoenix.LiveView
  # alias Phoenix.LiveViewTest.DOM
  alias AssetImportTest.Endpoint
  # , ClockLive, ClockControlsLive}

  @endpoint Endpoint
  @moduletag :capture_log

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  describe "live view" do
    @tag session: %{nest: []}
    test "static render", %{conn: conn} do
      conn = get(conn, "/thermo")
      assert html_response(conn, 200) =~ "The temp is: 0"

      {:ok, _view, html} = live(conn)
      assert html =~ "The temp is: 1"

      assert_current_imports([
        "thermostat",
        "thermostat/clock",
        "thermostat/clock/static_controls"
      ])
    end

    test "live render", %{conn: conn} do
      conn = get(conn, "/thermo")
      assert html_response(conn, 200) =~ "The temp is: 0"

      {:ok, _view, html} = live(conn)
      assert html =~ "The temp is: 1"

      assert_current_imports([
        "thermostat"
      ])
    end
  end

  defp assert_current_imports(expected_names) do
    expected_assets =
      Enum.reduce(expected_names, MapSet.new(), &MapSet.put(&2, hash(name_to_file(&1))))

    assert expected_assets == AssetImport.current_imports()
  end

  # defp assert_registered_imports(expected_names) do
  #   expected_assets =
  #     expected_names
  #     |> Enum.reduce(%{}, fn name, acc ->
  #       file = name_to_file(name)
  #       Map.put(acc, hash(file))
  #     end)

  #   assert {:ok, expected_assets} == AssetImport.registered_imports()
  # end

  defp name_to_file(name) do
    File.cwd!()
    |> Path.join("assets")
    |> Path.join(name)
    |> Path.relative_to(
      :asset_import
      |> Application.get_env(AssetImportTest.Assets)
      |> Keyword.get(:assets_path)
    )
    |> case do
      file = "/" <> _ ->
        file

      file ->
        Path.join(".", file)
    end
  end

  defp hash(value) do
    :crypto.hash(:sha256, to_string(AssetImportTest.Assets) <> "|./assets" <> String.slice(value, 1..-1))
    |> Base.encode64(padding: false)
    |> String.replace(~r/[^a-zA-Z0-9]+/, "")
    |> String.slice(0..7)
  end
end
