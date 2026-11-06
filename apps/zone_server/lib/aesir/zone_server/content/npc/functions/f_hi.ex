defmodule Aesir.ZoneServer.Content.Npc.Functions.FHi do
  @moduledoc """
  Returns a random greeting.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Content.Npc.Functions.FRand
  alias Aesir.ZoneServer.Script.Ctx

  @greetings ["Hi!", "Hello!", "Good day!", "How are you?", "Hello there."]

  @doc "Callable rAthena global function `F_Hi`; returns one of the greetings at random."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, _args), do: FRand.call(ctx, @greetings)
end
