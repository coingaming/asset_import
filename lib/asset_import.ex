defmodule AssetImport do
  @doc false
  require Logger
  import IO.ANSI

  defmacro __using__(opts) do
    module = __CALLER__.module
    app_name = Mix.Project.config() |> Keyword.fetch!(:app)

    Module.put_attribute(module, :asset_import_deps, [])

    assets_path =
      case Keyword.get(opts, :assets_path) do
        nil ->
          case config(module, :assets_path) do
            nil ->
              Path.join(File.cwd!(), "assets")

            value ->
              value
          end

        value ->
          Path.join(File.cwd!(), value)
      end

    files_module_ast =
      case config(module, :manifest_path) do
        nil ->
          nil

        manifest_file ->
          quote do
            defmodule Files do
              @manifest AssetImport.read_manifest(unquote(manifest_file)) |> Jason.decode!()
              @js_assets AssetImport.manifest_assets(@manifest, unquote(module), ".js")
              @css_assets AssetImport.manifest_assets(@manifest, unquote(module), ".css")

              defmacro unused_asset_script_files do
                assets = @js_assets |> Macro.escape()

                quote do
                  AssetImport.unused_imports(unquote(assets))
                end
              end

              defmacro unused_asset_style_files do
                assets = @css_assets |> Macro.escape()

                quote do
                  AssetImport.unused_imports(unquote(assets))
                end
              end

              defmacro asset_script_files do
                assets = @js_assets |> Macro.escape()

                quote do
                  AssetImport.used_imports(unquote(assets))
                end
              end

              defmacro asset_style_files do
                assets = @css_assets |> Macro.escape()

                quote do
                  AssetImport.used_imports(unquote(assets))
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

              def js_assets do
                @js_assets
              end

              def css_assets do
                @css_assets
              end

              def __phoenix_recompile__? do
                unquote(AssetImport.manifest_hash(manifest_file)) !=
                  AssetImport.manifest_hash(unquote(manifest_file))
              end
            end
          end
      end

    after_compile_ast =
      case config(module, :entrypoints_path) do
        nil ->
          nil

        :disabled ->
          nil

        entrypoints_file ->
          quote do
            def __after_compile__(_env, _bytecode) do
              AssetImport.write_entrypoints(
                unquote(assets_path),
                unquote(module),
                unquote(entrypoints_file)
              )
            end
          end
      end

    using_ast =
      case after_compile_ast do
        nil ->
          quote do
            defmacro __using__(_) do
              module = unquote(module)

              deps = Module.get_attribute(__CALLER__.module, :asset_import_deps)

              if is_nil(deps) do
                Module.put_attribute(__CALLER__.module, :asset_imports, Map.new())

                quote do
                  AssetImport.put_compiling_module(__MODULE__)

                  import unquote(__MODULE__)

                  @before_compile AssetImport
                end
              else
                Module.put_attribute(__CALLER__.module, :asset_import_deps, [
                  {unquote(app_name), __MODULE__} | deps
                ])

                quote do
                  @before_compile {AssetImport, :register_deps}
                end
              end
            end
          end

        _ ->
          quote do
            defmacro __using__(_) do
              deps = Module.get_attribute(__CALLER__.module, :asset_import_deps)

              if is_nil(deps) do
                Module.put_attribute(__CALLER__.module, :asset_imports, Map.new())
                module = unquote(module)

                quote do
                  AssetImport.put_compiling_module(__MODULE__)

                  import unquote(__MODULE__)

                  @before_compile AssetImport
                  @after_compile unquote(module)
                end
              else
                Module.put_attribute(__CALLER__.module, :asset_import_deps, [
                  {unquote(app_name), __MODULE__} | deps
                ])

                quote do
                  @before_compile {AssetImport, :register_deps}
                end
              end
            end
          end
      end

    asset_import_ast =
      quote do
        defmacro asset_import(socket_or_conn, name) do
          module = unquote(module)
          assets_path = unquote(assets_path)
          asset_hash = AssetImport.register_import(__CALLER__, module, assets_path, name)

          quote do
            AssetImport.asset_import(unquote(socket_or_conn), unquote(asset_hash))
          end
        end
      end

    [files_module_ast, using_ast, asset_import_ast, after_compile_ast]
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def __asset_imports__ do
        @asset_imports
      end
    end
  end

  defmacro register_deps(_env) do
    quote do
      def __asset_import_deps__ do
        @asset_import_deps
      end
    end
  end

  @doc false
  def write_entrypoints(assets_path, module, entrypoints_file) do
    deps =
      if function_exported?(module, :__asset_import_deps__, 0) do
        module.__asset_import_deps__()
      else
        []
      end

    app_deps = deps |> Enum.map(fn {app, _} -> app end)
    module_deps = deps |> Enum.map(fn {_, mod} -> mod end)

    case registered_imports(app_deps) do
      {:ok, imports} ->

        content =
          imports
          |> Enum.reduce([], fn
            {hash, {^module, file}}, acc ->
              [{hash, Path.join(".", Path.relative_to(file, assets_path))} | acc]

            {hash, {asset_module, file}}, acc ->
              if asset_module in module_deps do
                [{hash, relative_path(file, assets_path)} | acc]
              else
                acc
              end
          end)
          |> Enum.into(%{})
          |> Jason.encode!(pretty: true)

        case File.read(entrypoints_file) do
          {:ok, ^content} ->
            :ok

          _ ->
            File.write(entrypoints_file, content)
        end

      error ->
        error
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

    abs_path = Path.join(assets_path, name)

    unless File.exists?(abs_path) || File.exists?(abs_path <> ".js") do
      raise CompileError.exception(
              description: asset_not_found_error(assets_path, name),
              file: caller.file,
              line: caller.line
            )
    end

    rel_path =
      abs_path
      |> Path.relative_to(File.cwd!())
      |> case do
        file = "/" <> _ ->
          file

        file ->
          Path.join(".", file)
      end

    current_asset_imports = Module.get_attribute(caller_module, :asset_imports) || Map.new()
    asset_hash = hash(Atom.to_string(module) <> "|" <> rel_path)
    new_imports = Map.put(current_asset_imports, asset_hash, {module, abs_path})
    Module.put_attribute(caller_module, :asset_imports, new_imports)
    asset_hash
  end

  @doc false
  def registered_imports(deps) do
    case get_modules(deps) do
      {:ok, modules} ->
        {:ok,
         modules
         |> Enum.reduce(Map.new(), &Map.merge(&2, &1.__asset_imports__()))}

      error ->
        error
    end
  end

  @doc false
  def asset_import(socket_or_conn, asset_hash) do
    current_imports = Process.get(:asset_imports, MapSet.new())
    Process.put(:asset_imports, MapSet.put(current_imports, asset_hash))

    files_module =
      case Process.get(:asset_import_module) do
        nil ->
          module =
            socket_or_conn
            |> case do
              %{endpoint: endpoint} ->
                endpoint
              %{private: %{phoenix_endpoint: endpoint}} ->
                endpoint
            end
            |> Module.split()
            |> hd()
            |> Module.concat(Assets.Files)

          Process.put(:asset_import_module, module)
          module

        files_module ->
          files_module
      end

    if !is_nil(files_module) do
      files = imports_files(files_module.js_assets(), asset_hash) ++ imports_files(files_module.css_assets(), asset_hash)

      case files do
        [] ->
          nil

        files ->
          ~s|<div id="ai_#{asset_hash}" style="display: none" phx-hook="AssetImport" data-asset-files="#{files |> Enum.join(" ")}"></div>|
          |> Phoenix.HTML.raw()
      end
    end
  end

  defp imports_files(imports, asset_hash) do
    imports
    |> Map.get(asset_hash)
    |> case do
      nil ->
        []

      files ->
        files
        |> MapSet.to_list()
        |> Enum.sort()
    end
  end

  @doc false
  def current_imports do
    Process.get(:asset_imports) || MapSet.new()
  end

  @doc false
  def used_imports(assets) do
    current_imports()
    |> MapSet.put("runtime")
    |> Enum.reduce(MapSet.new(), &MapSet.union(&2, Map.get(assets, &1, MapSet.new())))
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc false
  def unused_imports(assets) do
    used_files =
      current_imports()
      |> MapSet.put("runtime")
      |> Enum.reduce(MapSet.new(), &MapSet.union(&2, Map.get(assets, &1, MapSet.new())))

    all_files =
      Enum.reduce(assets, MapSet.new(), fn {_, files}, acc ->
        MapSet.union(acc, files)
      end)

    all_files
    |> MapSet.difference(used_files)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc false
  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64(padding: false)
    |> String.replace(~r/[^a-zA-Z0-9]+/, "")
    |> String.slice(0..7)
  end

  @doc false
  def get_modules(deps) do
    compiling_modules =
      get_compiling_modules()
      |> MapSet.to_list()

    if Enum.all?(compiling_modules, &Code.ensure_loaded?/1) do
      {:ok,
       (compiling_modules ++ get_compiled_modules(deps))
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
  def get_compiled_modules(deps) do
    [Mix.Project.compile_path(), Enum.map(deps, &:code.lib_dir(&1, :ebin))]
    |> Enum.reduce([], fn path, acc ->
      path
      |> Path.join("*.beam")
      |> Path.wildcard()
      |> Enum.map(&beam_to_module/1)
      |> Kernel.++(acc)
    end)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  @doc false
  def manifest_hash(manifest_file) do
    manifest_file
    |> read_manifest()
    |> :erlang.md5()
  end

  @doc false
  def read_manifest(manifest_file) do
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
  def manifest_assets(manifest, module, extension) do
    base_url = config!(module, :assets_base_url)

    manifest
    |> Enum.filter(fn {_, output_file} ->
      Path.extname(output_file) == extension
    end)
    |> Enum.map(fn {input_file, output_file} ->
      {input_file, Path.join(base_url, output_file)}
    end)
    |> Enum.reduce(%{}, fn {input_file, output_file}, acc ->
      input_file
      |> Path.basename(extension)
      |> String.split("~")
      |> Enum.reduce(acc, fn hash, acc ->
        Map.put(acc, hash, MapSet.put(Map.get(acc, hash, MapSet.new()), output_file))
      end)
    end)
    |> Enum.into(%{})
  end

  defp relative_path(to, from) when is_binary(to) and is_binary(from) do
    relative_path(Path.split(to), Path.split(from))
  end

  defp relative_path([head | to], [head | from]) do
    relative_path(to, from)
  end

  defp relative_path(to, from) do
    Path.join(Enum.map(0..(length(from) - 1), fn _ -> ".." end) ++ to)
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

  @doc false
  def config(module, field, default \\ nil) do
    case Application.get_env(:asset_import, module) do
      nil ->
        default

      value ->
        case Keyword.get(value, field) do
          nil ->
            default

          value ->
            value
        end
    end
  end

  @doc false
  def config!(module, field) do
    case config(module, field) do
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

        raise CompileError.exception(description: "Missing config field #{inspect(field)}")

      value ->
        value
    end
  end
end
