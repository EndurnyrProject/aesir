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

  @doc """
  Raises for an rAthena constant the transpiler could not resolve.
  """
  @spec const!(atom()) :: no_return()
  def const!(name) do
    raise NotImplementedError,
      message: "unresolved rAthena constant: #{name}",
      buildin: name,
      args: []
  end
end
