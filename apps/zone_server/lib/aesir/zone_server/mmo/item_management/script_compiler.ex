defmodule Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler do
  @moduledoc """
  Boot-time compiler turning item `on_use` source strings into a single dispatch
  module.

  Every item whose `on_use` is non-nil contributes one
  `def on_use(<id>, ctx)` clause whose body is the parsed source; a final noop
  clause returns the context unchanged for any other id. All clauses live in the
  generated `Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts` module,
  which imports `Aesir.ZoneServer.Script.Dsl` so bare DSL calls resolve.

  Compilation is fail-fast: a malformed source raises while parsing and an
  `on_use` referencing an undefined DSL function raises at module-create time.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @target Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts

  @doc """
  Compiles the `on_use` script of every given item into `CompiledItemScripts`.

  Items with a nil `on_use` are ignored. Defaults to compiling every item from
  `Items.all/0`. Raises on a malformed or invalid script.
  """
  @spec compile_all!([ItemDefinition.t()]) :: :ok
  def compile_all!(items \\ Items.all()) do
    clauses =
      items
      |> Enum.reject(&is_nil(&1.on_use))
      |> Enum.map(&clause/1)

    body =
      quote do
        import Aesir.ZoneServer.Script.Dsl
        unquote_splicing(clauses ++ [fallback_clause()])
      end

    create_module!(body)
  end

  @spec create_module!(Macro.t()) :: :ok
  defp create_module!(body) do
    previous = Code.get_compiler_option(:ignore_module_conflict)
    Code.put_compiler_option(:ignore_module_conflict, true)

    try do
      Module.create(@target, body, Macro.Env.location(__ENV__))
      :ok
    after
      Code.put_compiler_option(:ignore_module_conflict, previous)
    end
  end

  @spec clause(ItemDefinition.t()) :: Macro.t()
  defp clause(%ItemDefinition{id: id, on_use: source}) do
    body = Code.string_to_quoted!(source)
    ctx_var = Macro.var(:ctx, nil)

    quote do
      def on_use(unquote(id), unquote(ctx_var)) do
        unquote(body)
      end
    end
  end

  @spec fallback_clause() :: Macro.t()
  defp fallback_clause do
    quote do
      def on_use(_id, ctx), do: ctx
    end
  end
end
