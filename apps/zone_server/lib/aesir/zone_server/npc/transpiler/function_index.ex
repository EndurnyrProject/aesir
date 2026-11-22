defmodule Aesir.ZoneServer.Npc.Transpiler.FunctionIndex do
  @moduledoc """
  Indexes generated global helpers by logical name and content scope.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Npc.ContentScope

  @type module_name() :: String.t()
  @type target() :: %{ContentScope.t() => module_name()}
  @type t() :: %{String.t() => target()}

  @type resolution() ::
          {:static, module_name()}
          | {:runtime, %{GameMode.t() => module_name()}}
          | :missing

  @typedoc "A generated helper and the scope in which it is defined."
  @type helper :: %{name: String.t(), scope: ContentScope.t(), module: module_name()}

  @typedoc "A duplicate or ambiguous definition of a global helper."
  @type error ::
          {:duplicate_helper, String.t(), ContentScope.t()}
          | {:ambiguous_helper, String.t(), :shared, GameMode.t()}

  @doc "Indexes helpers by name and scope, rejecting conflicting definitions."
  @spec build([helper()]) :: {:ok, t()} | {:error, [error()]}
  def build(functions) do
    {index, errors} =
      Enum.reduce(functions, {%{}, []}, fn function, {index, errors} ->
        targets = Map.get(index, function.name, %{})

        if Map.has_key?(targets, function.scope) do
          {index, [{:duplicate_helper, function.name, function.scope} | errors]}
        else
          ambiguity_errors = ambiguity_errors(function.name, function.scope, targets)
          index = Map.put(index, function.name, Map.put(targets, function.scope, function.module))
          {index, Enum.reverse(ambiguity_errors, errors)}
        end
      end)

    case Enum.reverse(errors) do
      [] -> {:ok, index}
      errors -> {:error, errors}
    end
  end

  defp ambiguity_errors(name, :shared, targets) do
    for scope <- [:renewal, :pre_renewal],
        Map.has_key?(targets, scope),
        do: {:ambiguous_helper, name, :shared, scope}
  end

  defp ambiguity_errors(name, scope, targets) when scope in [:renewal, :pre_renewal] do
    if Map.has_key?(targets, :shared), do: [{:ambiguous_helper, name, :shared, scope}], else: []
  end

  @spec resolve(t(), String.t(), ContentScope.t()) :: resolution()
  def resolve(index, name, :shared) do
    case Map.get(index, name, %{}) do
      %{shared: module} ->
        {:static, module}

      targets ->
        targets = Map.take(targets, [:renewal, :pre_renewal])
        if map_size(targets) == 0, do: :missing, else: {:runtime, targets}
    end
  end

  def resolve(index, name, caller_scope) when caller_scope in [:renewal, :pre_renewal] do
    case index |> Map.get(name, %{}) |> Map.take([:shared, caller_scope]) |> Map.values() do
      [module] -> {:static, module}
      [] -> :missing
    end
  end
end
