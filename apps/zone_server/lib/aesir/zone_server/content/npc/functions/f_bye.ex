defmodule Aesir.ZoneServer.Content.Npc.Functions.FBye do
  @moduledoc """
  Returns a random farewell.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Content.Npc.Functions.FRand
  alias Aesir.ZoneServer.Script.Ctx

  @farewells [
    "Bye. See you again.",
    "Later.",
    "Goodbye.",
    "Good luck!",
    "Have a nice day!",
    "Byebye!!!"
  ]

  @doc "Callable rAthena global function `F_Bye`; returns one of the farewells at random."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, _args), do: FRand.call(ctx, @farewells)
end
