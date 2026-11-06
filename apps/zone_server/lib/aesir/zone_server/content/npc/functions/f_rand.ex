defmodule Aesir.ZoneServer.Content.Npc.Functions.FRand do
  @moduledoc """
  Picks one of its arguments at random.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `F_Rand(value, ...)`; returns one of `args` at random.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), term()}
  def call(ctx, args), do: {ctx, Enum.at(args, :rand.uniform(length(args)) - 1, 0)}
end
