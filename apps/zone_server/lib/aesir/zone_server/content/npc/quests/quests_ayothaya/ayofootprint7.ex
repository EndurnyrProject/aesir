defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Ayofootprint7 do
  @moduledoc """
  Reveals a clue along Annon's trail through the dungeon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayo_dun02",
        x: 77,
        y: 213,
        dir: 0,
        sprite: 139,
        name: "AyoFootprint7",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: follow_trail(ctx)

  @impl true
  def on_talk(ctx), do: follow_trail(ctx)

  defp follow_trail(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 10 and Enum.random(1..3) < 2 do
      ctx
      |> emotion(:surprise, playerattached(ctx))
      |> mes("^3355FFWhere is he...?")
      |> mes("He seems to have gone")
      |> mes("deep into the dungeon.")
      |> mes("Just looking for this")
      |> mes("guy is exhausting...^000000")
      |> set_char_var(:thai_find, 11)
      |> close()
    else
      ctx
    end
  end
end
