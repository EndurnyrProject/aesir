defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Ayofootprint2 do
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
        x: 74,
        y: 142,
        dir: 0,
        sprite: 139,
        name: "AyoFootprint2",
        scope: :shared,
        trigger: {2, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: follow_trail(ctx)

  @impl true
  def on_talk(ctx), do: follow_trail(ctx)

  defp follow_trail(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 5 and Enum.random(1..3) < 2 do
      ctx
      |> emotion(:think, playerattached(ctx))
      |> mes(
        "^3355FFYou find another set of footprints. It seems that somebody was running away from something. These prints are heading to the ^5C3317East^3355FF. You'd better follow them to see what"
      )
      |> mes("you can find.^000000")
      |> set_char_var(:thai_find, 6)
      |> close()
    else
      ctx
    end
  end
end
