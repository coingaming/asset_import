defmodule AssetImport do

  defmacro __using__(_opts) do
    # assets_path = Keyword.get(opts, :assets_path, "assets/")
    # manifest_file = Keyword.get(opts, :manifest_file , "priv/manifest.json")

    quote location: :keep do
      defmacro __using__(_) do
        quote location: :keep do
          import unquote(__MODULE__)
          @before_compile AssetImport
        end
      end
      defmacro asset_import(name) do

        IO.inspect(File.cwd!())


        AssetImport.put_compiling_module(__CALLER__.module)

        current_asset_imports = Module.get_attribute(__CALLER__.module, :asset_imports) || MapSet.new()
        new_asset_imports = MapSet.put(current_asset_imports, name)
        Module.put_attribute(__CALLER__.module, :asset_imports, new_asset_imports)

        quote location: :keep do
          AssetImport.register_import(unquote(name))
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __asset_imports__ do
        @asset_imports
      end
    end
  end

  def register_import(name) do
    current_imports = Process.get(:asset_imports, MapSet.new())
    Process.put(:asset_imports, MapSet.put(current_imports, name))
  end

  def imports do
    Process.get(:asset_imports)
  end

  def hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64(padding: false)
    |> String.slice(0..7)
  end

  def get_scripts() do

  end

  def get_styles() do

  end

  def get_asset_imports() do
    get_modules()
    |> Enum.reduce(MapSet.new(), &MapSet.union(&2, &1.__asset_imports__()))
  end

  def get_modules() do
    compiling_modules = get_compiling_modules()

    fetch_compiled_modules()
    |> Enum.filter(&function_exported(&1, :__asset_imports__, 0))
    |> MapSet.new()
    |> MapSet.union(compiling_modules)
  end

  def put_compiling_module(module) do
    name = compiling_modules_agent_name()
    Agent.start(fn -> MapSet.new() end, name: name)
    Agent.update(name, &MapSet.put(&1, module))
  end

  defp get_compiling_modules do
    name = compiling_modules_agent_name()

    if Process.whereis(name) do
      Agent.get(name, & &1)
    else
      MapSet.new()
    end
  end

  defp compiling_modules_agent_name() do
    (Atom.to_string(Mix.Project.config()[:app]) <> "_asset_imports")
    |> String.to_atom()
  end

  defp fetch_compiled_modules() do
    :code.get_path()
    |> Enum.flat_map(fn dir ->
      dir
      |> File.dir?()
      |> case do
        true ->
          dir
          |> File.ls!()
          |> Stream.filter(&(String.starts_with?(&1, "Elixir.") && String.ends_with?(&1, ".beam")))
          |> Enum.map(&(Regex.replace(~r/(\.beam)$/, &1, fn _, _ -> "" end) |> String.to_atom()))

        false ->
          []
      end
    end)
    |> MapSet.new()
  end

  defp function_exported(module, function, arity) do
    try do
      module.__info__(:functions)
    rescue
      _ -> :ok
    end

    _ = Code.ensure_loaded(module)
    :erlang.function_exported(module, function, arity)
  end

  # defp read_manifest(manifest_file) do
  #   manifest_file
  #   |> File.read()
  #   |> case do
  #     {:ok, body} ->
  #       body

  #     {:error, _} ->
  #       IO.warn("Asset manifest file (#{manifest_file}) not found. Build assets first.")
  #       "{}"
  #   end
  # end

  # defp manifest_assets(manifest, extension, asset_name) do
  #   manifest
  #   |> Enum.filter(fn {name, file} ->
  #     Path.extname(file) == extension &&
  #       (String.contains?(name, "~#{asset_name}~") ||
  #          String.contains?(name, "~#{asset_name}.") ||
  #          String.starts_with?(name, "#{asset_name}~") ||
  #          String.starts_with?(name, "#{asset_name}."))
  #   end)
  #   |> Enum.map(fn {_, file} -> file end)
  #   |> Enum.sort()
  # end
end
