defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Deniroz do
  @moduledoc """
  Shows Deniroz repeatedly chasing a casino jackpot.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in02",
        x: 89,
        y: 72,
        dir: 4,
        sprite: 89,
        name: "Deniroz",
        scope: :shared,
        unique_name: "Deniroz#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Deniroz]")
    |> mes("All I need is for this")
    |> mes("little steel bead to fall")
    |> mes("into the right hole. Then,")
    |> mes("I'll win the jackpot. Alright.")
    |> mes("Here goes. One last time...")
    |> next()
    |> mes("[Deniroz]")
    |> mes("No! No, I was so close!")
    |> mes("Alright, next time I should")
    |> mes("be even closer, right? Yeah.")
    |> mes("Okay, this time will be the")
    |> mes("last time. Not again! Alright,")
    |> mes("j-just one more t-time...")
    |> close()
  end
end
