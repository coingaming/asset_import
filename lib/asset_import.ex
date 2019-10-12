defmodule AssetImport do
  @doc false
  require Logger
  import IO.ANSI

  defmacro __using__(opts) do
    assets_path = Keyword.get(opts, :assets_path, "assets")
    module = __CALLER__.module

    quote do
      defmodule Files do
        @manifest AssetImport.read_manifest(unquote(module)) |> Jason.decode!()

        defmacro unused_asset_script_files do
          manifest =
            @manifest
            |> AssetImport.manifest_assets_by_extension(unquote(module), ".js")
            |> Macro.escape()

          quote do
            AssetImport.unused_imports(unquote(manifest))
          end
        end

        defmacro unused_asset_style_files do
          manifest =
            @manifest
            |> AssetImport.manifest_assets_by_extension(unquote(module), ".css")
            |> Macro.escape()

          quote do
            AssetImport.unused_imports(unquote(manifest))
          end
        end

        defmacro asset_script_files do
          manifest =
            @manifest
            |> AssetImport.manifest_assets_by_extension(unquote(module), ".js")
            |> Macro.escape()

          quote do
            AssetImport.used_imports(unquote(manifest))
          end
        end

        defmacro asset_style_files do
          manifest =
            @manifest
            |> AssetImport.manifest_assets_by_extension(unquote(module), ".css")
            |> Macro.escape()

          quote do
            AssetImport.used_imports(unquote(manifest))
          end
        end

        def preload_asset_scripts do
          AssetImport.render_preloads(unused_asset_script_files(), as: "script")
        end

        def preload_asset_styles do
          AssetImport.render_preloads(unused_asset_style_files(), as: "style")
        end

        def asset_scripts do
          AssetImport.render_scripts(asset_script_files())
        end

        def asset_styles do
          AssetImport.render_styles(asset_style_files())
        end

        def __phoenix_recompile__? do
          unquote(AssetImport.manifest_hash(module)) != AssetImport.manifest_hash(unquote(module))
        end
      end

      @manifest AssetImport.read_manifest(unquote(module)) |> Jason.decode!()

      defmacro __using__(_) do
        Module.put_attribute(__CALLER__.module, :asset_imports, Map.new())
        module = unquote(module)
        quote do
          AssetImport.put_compiling_module(__MODULE__)

          import unquote(__MODULE__)
          import unquote(__MODULE__).Files, except: [__phoenix_recompile__?: 0]

          @before_compile AssetImport
          @after_compile unquote(module)
        end
      end

      defmacro asset_import(name) do
        asset_hash = AssetImport.register_import(__CALLER__, unquote(module), unquote(assets_path), name)

        files =
          @manifest
          |> AssetImport.manifest_assets_by_hash(unquote(module), asset_hash)

        quote do
          AssetImport.asset_import(unquote(asset_hash), unquote(files))
        end
      end

      def __after_compile__(_env, _bytecode) do
        case AssetImport.registered_imports() do
          {:ok, imports} ->
            AssetImport.write_entrypoints(unquote(module), imports)

          error ->
            error
        end
      end

      def __phoenix_recompile__? do
        unquote(AssetImport.manifest_hash(module)) != AssetImport.manifest_hash(unquote(module))
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
  def write_entrypoints(module, imports) do
    content = Jason.encode!(imports, pretty: true)

    case config(module, :entrypoints_path) do
      :disabled ->
        :ok

      file_path ->
        case File.read(file_path) do
          {:ok, ^content} ->
            :ok

          _ ->
            File.write(file_path, content)
        end
    end
  end

  @doc false
  def render_preloads(files, as: as) do
    files
    |> Enum.map(&~s|<link rel="preload" href="#{&1}" as="#{as}">|)
    |> Enum.join("")
    |> Phoenix.HTML.raw()
  end

  @doc false
  def render_scripts(scripts) do
    scripts
    |> Enum.map(&~s|<script type="text/javascript" src="#{&1}"></script>|)
    |> Enum.join("")
    |> Phoenix.HTML.raw()
  end

  @doc false
  def render_styles(styles) do
    styles
    |> Enum.map(&~s|<link rel="stylesheet" type="text/css" href="#{&1}"/>|)
    |> Enum.join("")
    |> Phoenix.HTML.raw()
  end

  @doc false
  def register_import(caller, module, assets_path, name) do
    caller_module = caller.module

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
      |> Path.relative_to(config(module, :assets_path))
      |> case do
        file = "/" <> _ ->
          file

        file ->
          Path.join(".", file)
      end

    current_asset_imports = Module.get_attribute(caller_module, :asset_imports) || Map.new()
    asset_hash = hash(rel_path)
    new_imports = Map.put(current_asset_imports, asset_hash, rel_path)
    Module.put_attribute(caller_module, :asset_imports, new_imports)
    asset_hash
  end

  @doc false
  def registered_imports() do
    case get_modules() do
      {:ok, modules} ->
        {:ok,
         modules
         |> Enum.reduce(Map.new(), &Map.merge(&2, &1.__asset_imports__()))}

      error ->
        error
    end
  end

  @doc false
  def asset_import(asset_hash, imports) do
    current_imports = Process.get(:asset_imports, MapSet.new())
    Process.put(:asset_imports, MapSet.put(current_imports, asset_hash))

    files =
      imports
      |> Enum.sort()
      |> Enum.map(fn {_, file} -> file end)
      |> Enum.join(" ")

    case files do
      "" ->
        nil

      files ->
        ~s|<div style="display: none" phx-hook="AssetImport" data-asset-files="#{files}"></div>|
        |> Phoenix.HTML.raw()
    end
  end

  @doc false
  def current_imports do
    Process.get(:asset_imports) || MapSet.new()
  end

  @doc false
  def used_imports(manifest) do
    current_imports()
    |> MapSet.put("runtime")
    |> Enum.reduce([], &(&2 ++ Map.get(manifest, &1, [])))
    |> Enum.sort()
    |> Enum.map(fn {_, file} -> file end)
  end

  @doc false
  def unused_imports(manifest) do
    used_files =
      current_imports()
      |> MapSet.put("runtime")
      |> Enum.reduce(MapSet.new(), &MapSet.union(&2, manifest |> Map.get(&1, []) |> MapSet.new()))

    all_files =
      Enum.reduce(manifest, MapSet.new(), fn {_, files}, acc ->
        MapSet.union(acc, MapSet.new(files))
      end)

    all_files
    |> MapSet.difference(used_files)
    |> Enum.sort()
    |> Enum.map(fn {_, file} -> file end)
  end

  @doc false
  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64(padding: false)
    |> String.replace(~r/[^a-zA-Z0-9]+/, "")
    |> String.slice(0..7)
  end

  @doc false
  def get_modules() do
    compiling_modules =
      get_compiling_modules()
      |> MapSet.to_list()

    if Enum.all?(compiling_modules, &Code.ensure_loaded?/1) do
      {:ok,
       (compiling_modules ++ get_compiled_modules())
       |> Enum.filter(
         &(Code.ensure_loaded?(&1) and function_exported?(&1, :__asset_imports__, 0))
       )
       |> MapSet.new()}
    else
      {:error, :still_compiling}
    end
  end

  @doc false
  def put_compiling_module(module) do
    Agent.start(fn -> MapSet.new() end, name: __MODULE__)
    Agent.update(__MODULE__, &MapSet.put(&1, module))
  end

  @doc false
  def get_compiling_modules do
    if Process.whereis(__MODULE__) do
      Agent.get(__MODULE__, & &1)
    else
      MapSet.new()
    end
  end

  @doc false
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
  def manifest_hash(module) do
    module
    |> read_manifest()
    |> :erlang.md5()
  end

  @doc false
  def read_manifest(module) do
    manifest_file = config(module, :manifest_path)

    manifest_file
    |> File.read()
    |> case do
      {:ok, body} ->
        body

      {:error, _} ->
        # IO.warn("Asset manifest file (#{manifest_file}) not found. Build assets first.", [])
        "{}"
    end
  end

  @doc false
  def manifest_assets_by_extension(manifest, module, extension) do
    base_url = config(module, :assets_base_url)

    manifest
    |> Enum.filter(fn {_, file} ->
      Path.extname(file) == extension
    end)
    |> Enum.reduce(Map.new(), fn {key, file}, acc ->
      String.split(Path.basename(key, extension), "~")
      |> Enum.reduce(acc, fn name, acc ->
        [order_str | _] = file |> Path.basename() |> String.split("-")
        {order, ""} = Integer.parse(order_str)
        Map.put(acc, name, [{order, Path.join(base_url, file)} | Map.get(acc, name, [])])
      end)
    end)
  end

  @doc false
  def manifest_assets_by_hash(manifest, module, asset_hash) do
    base_url = config(module, :assets_base_url)

    manifest
    |> Enum.reduce([], fn {key, file}, acc ->
      String.split(Path.basename(key, Path.extname(key)), "~")
      |> Enum.reduce(acc, fn
        ^asset_hash, acc ->
          [order_str | _] = file |> Path.basename() |> String.split("-")
          {order, ""} = Integer.parse(order_str)
          [{order, Path.join(base_url, file)} | acc]

        _, acc ->
          acc
      end)
    end)
  end

  defp asset_not_found_error(assets_path, name) do
    file_path = assets_path |> Path.join(name)
    dir_path = file_path |> Path.join("index.js")

    if Path.extname(name) == ".js" do
      "\n\nAsset #{green()}#{file_path}#{default_color()} not found.\n"
    else
      "\n\nAsset #{red()}#{file_path}#{default_color()} not found. " <>
        "Please create either #{green()}#{file_path}.js#{default_color()} or " <>
        "#{green()}#{dir_path}#{default_color()}.\n"
    end
  end

  defp config(module, field) do
    case Application.get_env(:asset_import, module) do
      nil ->
        """
        Missing `:asset_import` config for `#{inspect(module)}`.

        Example config:

            config :asset_import, #{inspect(module)},
              assets_base_url: "/",
              assets_path: Path.expand("assets"),
              manifest_path: Path.expand("priv/static/manifest.json"),
              entrypoints_path: Path.expand("assets/entrypoints.json")
        """
        |> IO.ANSI.Docs.print()

        raise CompileError.exception(description: "Missing config field #{inspect(field)}")

      value ->
        case Keyword.get(value, field) do
          nil ->
            """
            Missing `:asset_import` config field `#{inspect(field)}``.

            Example config:

                config :asset_import, #{inspect(module)},
                  assets_base_url: "/",
                  assets_path: Path.expand("assets"),
                  manifest_path: Path.expand("priv/static/manifest.json"),
                  entrypoints_path: Path.expand("assets/entrypoints.json")
            """
            |> IO.ANSI.Docs.print()

          value ->
            value
        end
    end
  end
end
