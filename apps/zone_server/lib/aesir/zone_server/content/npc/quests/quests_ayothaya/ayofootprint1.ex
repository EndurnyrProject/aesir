defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Ayofootprint1 do
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
        map: "ayo_dun01",
        x: 255,
        y: 62,
        dir: 0,
        sprite: 139,
        name: "AyoFootprint1",
        scope: :shared,
        trigger: {2, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: follow_trail(ctx)

  @impl true
  def on_talk(ctx), do: follow_trail(ctx)

  defp follow_trail(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 4 and Enum.random(1..3) < 2 do
      ctx
      |> emotion(:surprise, playerattached(ctx))
      |> mes(
        "^3355FFYou find footprints heading to the ^5C3317North^3355FF. It looks like somebody was in quite a hurry, just like the villager said!^000000"
      )
      |> set_char_var(:thai_find, 5)
      |> changequest(12032, 12033)
      |> close()
    else
      ctx
    end
  end
end
