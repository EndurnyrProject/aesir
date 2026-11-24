defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Girl365170 do
  @moduledoc """
  A girl enjoys the warmth of a stove.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 365,
        y: 170,
        dir: 3,
        sprite: 793,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl#Hu"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Girl]")
    |> mes("I love sitting in front of a stove because it makes me warm~")
    |> mes("Ah...it is so warm and relaxing...and now I feel sleepy...Zzzzz Zzzz...")
    |> close()
  end
end
