defmodule Aesir.ZoneServer.Script.NotImplementedError do
  @moduledoc """
  Raised at runtime when a transpiled script reaches an rAthena buildin or
  constant that has no Aesir implementation yet.

  The message names the missing piece so crash logs double as the
  implementation priority list.
  """

  defexception [:message, :buildin, :args]
end

defmodule Aesir.ZoneServer.Script.Todo do
  @moduledoc """
  Runtime stubs for transpiled scripts.

  `Aesir.ZoneServer.Script.Dsl.todo/3` covers unimplemented buildins in
  statement position; `const!/1` covers unresolvable rAthena constants in
  expression position. Both raise `NotImplementedError`.
  """

  alias Aesir.ZoneServer.Script.NotImplementedError

  # The raise goes through apply/3 so the compiler cannot infer no_return;
  # otherwise every `ctx = todo(...)` / `v == Todo.call!(...)` in the
  # thousands of generated modules would emit a type warning.
  @doc """
  Raises for an rAthena buildin (or variable scope) reached in expression
  position with no Aesir implementation yet.
  """
  @spec call!(atom(), [term()]) :: term()
  def call!(name, args) do
    apply(__MODULE__, :raise!, [
      "rAthena buildin not implemented: #{name}(#{inspect(args)})",
      name,
      args
    ])
  end

  @doc """
  Raises for an rAthena constant the transpiler could not resolve.
  """
  @spec const!(atom()) :: term()
  def const!(name) do
    apply(__MODULE__, :raise!, ["unresolved rAthena constant: #{name}", name, []])
  end

  @doc false
  @spec raise!(String.t(), atom(), [term()]) :: no_return()
  def raise!(message, buildin, args) do
    raise NotImplementedError, message: message, buildin: buildin, args: args
  end
end
