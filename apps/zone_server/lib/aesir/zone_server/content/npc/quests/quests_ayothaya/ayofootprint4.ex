defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Ayofootprint4 do
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
        x: 17,
        y: 257,
        dir: 0,
        sprite: 139,
        name: "AyoFootprint4",
        scope: :shared,
        trigger: {2, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: follow_trail(ctx)

  @impl true
  def on_talk(ctx), do: follow_trail(ctx)

  defp follow_trail(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 7 and Enum.random(1..3) < 2 do
      ctx
      |> emotion(:aha, playerattached(ctx))
      |> mes("^3355FFAs you follow the footprints,")
      |> mes(
        "you arrive at the '^5C3317Entrance of the Shrine^3355FF.' Whoever this person was, he just ran into the second level.^000000"
      )
      |> set_char_var(:thai_find, 8)
      |> close()
    else
      ctx
    end
  end
end
