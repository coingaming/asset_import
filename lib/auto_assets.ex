defmodule AutoAssets do

  defmacro __using__(_opts) do
    # assets_path = Keyword.get(opts, :assets_path, "assets/")
    # manifest_file = Keyword.get(opts, :manifest_file , "priv/manifest.json")

    quote location: :keep do
      defmacro __using__(_) do
        quote location: :keep do
          import unquote(__MODULE__)
          @before_compile AutoAssets
        end
      end
      defmacro import_assets(name) do
        AutoAssets.put_compiling_module(__CALLER__.module)

        current_asset_imports = Module.get_attribute(__CALLER__.module, :asset_imports) || MapSet.new()
        new_asset_imports = MapSet.put(current_asset_imports, name)
        Module.put_attribute(__CALLER__.module, :asset_imports, new_asset_imports)

        quote location: :keep do
          AutoAssets.register_import(unquote(name))
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
    current_imports = Process.get(:auto_assets_imports, MapSet.new())
    Process.put(:auto_assets_imports, MapSet.put(current_imports, name))
  end

  def imports do
    Process.get(:auto_assets_imports)
  end

  def get_asset_imports(caller_module) do
    get_modules(caller_module)
    |> Enum.reduce(MapSet.new(), &MapSet.union(&2, &1.__asset_imports__()))
  end

  def get_modules(caller_module) do
    compiling_modules = get_compiling_modules()

    fetch_compiled_modules(caller_module)
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
    (Atom.to_string(Mix.Project.config()[:app]) <> "_auto_assets")
    |> String.to_atom()
  end

  defp fetch_compiled_modules(module) do
    root_module =
      module
      |> Module.split()
      |> Enum.slice(0..0)
      |> Module.concat()
      |> Atom.to_string()

    :code.get_path()
    |> Enum.flat_map(fn dir ->
      dir
      |> File.dir?()
      |> case do
        true ->
          dir
          |> File.ls!()
          |> Stream.filter(&(String.starts_with?(&1, root_module) && String.ends_with?(&1, ".beam")))
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
