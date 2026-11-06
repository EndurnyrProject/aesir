defmodule Aesir.ZoneServer.Content.Npc.Functions.FSexmes do
  @moduledoc """
  Returns the argument matching the attached player's sex.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `F_SexMes(female, male)`; returns the first argument for a
  female character and the second for a male one.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), term()}
  def call(ctx, args), do: {ctx, Enum.at(args, sex(ctx), 0)}
end
