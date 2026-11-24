defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Ayofootprint3 do
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
        x: 244,
        y: 256,
        dir: 2,
        sprite: 139,
        name: "AyoFootprint3",
        scope: :shared,
        trigger: {2, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: follow_trail(ctx)

  @impl true
  def on_talk(ctx), do: follow_trail(ctx)

  defp follow_trail(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 6 and Enum.random(1..3) < 2 do
      ctx
      |> emotion(:stare_about, playerattached(ctx))
      |> mes("^3355FFThe footprints end around this area. Whoever was running must")
      |> mes(
        "have been exhausted and stumbled on something. Perhaps the owner of the footprints is nearby...^000000"
      )
      |> set_char_var(:thai_find, 7)
      |> close()
    else
      ctx
    end
  end
end
