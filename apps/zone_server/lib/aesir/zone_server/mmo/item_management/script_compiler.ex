defmodule Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler do
  @moduledoc """
  Boot-time compiler turning item `on_use` source strings into a single dispatch
  module.

  Every item whose `on_use` is non-nil contributes one
  `def on_use(<id>, ctx)` clause whose body is the parsed source, catching the
  script end a halting DSL command throws and returning its ctx; a final noop
  clause returns the context unchanged for any other id. All clauses live in the
  generated `Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts` module,
  which imports `Aesir.ZoneServer.Script.Dsl` so bare DSL calls resolve.

  Compilation is fail-fast: a malformed source raises while parsing and an
  `on_use` referencing an undefined DSL function raises at module-create time.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDialogs
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @target Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts

  @doc """
  Compiles the `on_use` script of every given item into `CompiledItemScripts`.

  Items with a nil `on_use` are ignored. Defaults to compiling every item from
  `Items.all/0`. Raises on a malformed or invalid script.
  """
  @spec compile_all!([ItemDefinition.t()]) :: :ok
  def compile_all!(items \\ Items.all()) do
    {clauses, dialog_clauses} =
      items
      |> Enum.reject(&is_nil(&1.on_use))
      |> Enum.map(&clause/1)
      |> Enum.unzip()

    body =
      quote do
        alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDialogs
        alias Aesir.ZoneServer.Script.Rathena
        import Aesir.ZoneServer.Script.Dsl
        unquote_splicing(clauses ++ [fallback_clause()])

        @doc "Whether this item's compiled source stages a destination dialog."
        @spec interactive?(integer()) :: boolean()
        unquote_splicing(Enum.reject(dialog_clauses, &is_nil/1))
        def interactive?(_id), do: false
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

  @spec clause(ItemDefinition.t()) :: {Macro.t(), Macro.t() | nil}
  defp clause(%ItemDefinition{id: id, on_use: source}) do
    body = Code.string_to_quoted!(source)
    ctx_var = Macro.var(:ctx, nil)
    interactive? = interactive_source?(body)

    on_use =
      quote do
        def on_use(unquote(id), unquote(ctx_var)) do
          unquote(body)
        catch
          :throw, {:script_end, %Aesir.ZoneServer.Script.Ctx{} = ended} -> ended
        end
      end

    dialog_clause =
      if interactive? do
        quote do
          def interactive?(unquote(id)), do: true
        end
      end

    {on_use, dialog_clause}
  end

  defp interactive_source?(
         {{:., _, [{:__aliases__, _, [:ItemDialogs]}, :stage]}, _,
          [{:ctx, _, context}, helper, args]}
       )
       when is_atom(context) do
    case ItemDialogs.target({helper, args}) do
      {:ok, _module} -> true
      :error -> raise ArgumentError, "invalid item-dialog request"
    end
  end

  defp interactive_source?(body) do
    {_body, staged?} =
      Macro.prewalk(body, false, fn
        {{:., _, [{:__aliases__, _, aliases}, :stage]}, _, _args} = node, found ->
          {node, found or List.last(aliases) == :ItemDialogs}

        node, found ->
          {node, found}
      end)

    if staged?, do: raise(ArgumentError, "item-dialog staging must be the entire item script")
    false
  end

  @spec fallback_clause() :: Macro.t()
  defp fallback_clause do
    quote do
      def on_use(_id, ctx), do: ctx
    end
  end
end
