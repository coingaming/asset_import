defmodule AssetImport do
  alias IO.ANSI

  require Logger

  defmacro __using__(opts) do
    assets_path = Keyword.get(opts, :assets_path, "assets")

    quote do
      defmodule Files do
        defmacro scripts() do
          manifest =
            AssetImport.manifest_assets(".js")
            |> Macro.escape()

          quote do
            AssetImport.imports(unquote(manifest))
          end
        end

        defmacro styles() do
          manifest =
            AssetImport.manifest_assets(".css")
            |> Macro.escape()

          quote do
            AssetImport.imports(unquote(manifest))
          end
        end

        def __phoenix_recompile__? do
          unquote(AssetImport.manifest_hash()) != AssetImport.manifest_hash()
        end
      end

      defmacro __using__(_) do
        Module.put_attribute(__CALLER__.module, :asset_imports, Map.new())

        quote do
          import unquote(__MODULE__)

          import unquote(__MODULE__).Files,
            only: [scripts: 0, styles: 0]

          @before_compile AssetImport
          @after_compile AssetImport
        end
      end

      defmacro asset_import(name) do
        asset_hash = AssetImport.register_import(__CALLER__, unquote(assets_path), name)

        quote do
          AssetImport.asset_import(unquote(asset_hash))
        end
      end
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def __asset_imports__ do
        @asset_imports
      end
    end
  end

  @doc false
  def __after_compile__(env, _bytecode) do
    write_entrypoints(env)
  end

  defp write_entrypoints(_env) do
    content = Jason.encode!(AssetImport.get_asset_imports(), pretty: true)
    file_path = config(:entrypoints_path)

    case File.read(file_path) do
      {:ok, ^content} ->
        :ok

      _ ->
        Logger.info("Writing assets endpoints (#{content |> String.length()}B)")
        :ok = File.write(file_path, content)
    end
  end

  @doc false
  def register_import(caller, assets_path, name) do
    module = caller.module

    abs_path =
      File.cwd!()
      |> Path.join(assets_path)
      |> Path.join(name)

    unless File.exists?(abs_path) || File.exists?(abs_path <> ".js") do
      raise CompileError.exception(
              description: asset_not_found_error(assets_path, name),
              file: caller.file,
              line: caller.line
            )
    end

    rel_path =
      abs_path
      |> Path.relative_to(config(:assets_path))
      |> case do
        file = "/" <> _ ->
          file

        file ->
          Path.join(".", file)
      end

    put_compiling_module(module)
    current_asset_imports = Module.get_attribute(module, :asset_imports) || Map.new()
    asset_hash = hash(rel_path)
    new_imports = Map.put(current_asset_imports, asset_hash, rel_path)
    Module.put_attribute(module, :asset_imports, new_imports)
    asset_hash
  end

  @doc false
  def asset_import(asset_hash) do
    current_imports = Process.get(:asset_imports, MapSet.new())
    Process.put(:asset_imports, MapSet.put(current_imports, asset_hash))
  end

  def current_imports do
    Process.get(:asset_imports) || MapSet.new()
  end

  @doc false
  def imports(manifest) do
    current_imports()
    |> MapSet.put("runtime")
    |> Enum.reduce([], &(&2 ++ Map.get(manifest, &1, [])))
    |> Enum.map(fn {_, file} -> file end)
    |> Enum.sort()
  end

  @doc false
  def get_asset_imports() do
    get_modules()
    |> Enum.reduce(Map.new(), &Map.merge(&2, &1.__asset_imports__()))
  end

  @doc false
  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64(padding: false)
    |> String.replace(~r/[^a-zA-Z0-9]+/, "")
    |> String.slice(0..7)
  end

  def get_modules() do
    compiling_modules = get_compiling_modules()

    get_compiled_modules()
    |> Stream.filter(&(Code.ensure_loaded?(&1) and function_exported?(&1, :__asset_imports__, 0)))
    |> MapSet.new()
    |> MapSet.union(compiling_modules)
  end

  defp put_compiling_module(module) do
    name = compiling_modules_agent_name()
    Agent.start(fn -> MapSet.new() end, name: name)
    Agent.update(name, &MapSet.put(&1, module))
  end

  def get_compiling_modules do
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

  @doc """
  Returns all compiled modules in a project.
  """
  def get_compiled_modules do
    Mix.Project.compile_path()
    |> Path.join("*.beam")
    |> Path.wildcard()
    |> Enum.map(&beam_to_module/1)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  @doc false
  def manifest_hash do
    read_manifest()
    |> :erlang.md5()
  end

  defp read_manifest do
    manifest_file = config(:manifest_path)

    manifest_file
    |> File.read()
    |> case do
      {:ok, body} ->
        body

      {:error, _} ->
        IO.warn("Asset manifest file (#{manifest_file}) not found. Build assets first.", [])
        "{}"
    end
  end

  @doc false
  def manifest_assets(extension) do
    read_manifest()
    |> Jason.decode!()
    |> Enum.filter(fn {_, file} ->
      Path.extname(file) == extension
    end)
    |> Enum.reduce(Map.new(), fn {key, file}, acc ->
      String.split(Path.basename(key, extension), "~")
      |> Enum.reduce(acc, fn name, acc ->
        [order_str | _] = String.split(file, "-")
        {order, ""} = Integer.parse(order_str)
        Map.put(acc, name, [{order, file} | Map.get(acc, name, [])])
      end)
    end)
  end

  defp asset_not_found_error(assets_path, name) do
    file_path = assets_path |> Path.join(name)
    dir_path = file_path |> Path.join("index.js")

    if Path.extname(name) == ".js" do
      "\n\nAsset #{ANSI.green()}#{file_path}#{ANSI.default_color()} not found.\n"
    else
      "\n\nAsset #{ANSI.red()}#{file_path}#{ANSI.default_color()} not found. " <>
        "Please create either #{ANSI.green()}#{file_path}.js#{ANSI.default_color()} or " <>
        "#{ANSI.green()}#{dir_path}#{ANSI.default_color()}.\n"
    end
  end

  defp config(field) do
    case Application.get_env(:asset_import, field) do
      nil ->
        """
        Missing `:asset_import` config field `#{inspect(field)}`.

        Example config:

            config :asset_import,
              assets_path: File.cwd!() |> Path.join("assets"),
              manifest_path: File.cwd!() |> Path.join("priv/static/manifest.json"),
              entrypoints_path: File.cwd!() |> Path.join("assets/entrypoints.json")
        """
        |> IO.ANSI.Docs.print()

        raise CompileError.exception(description: "Missing config field #{inspect(field)}")

      value ->
        value
    end
  end
end
