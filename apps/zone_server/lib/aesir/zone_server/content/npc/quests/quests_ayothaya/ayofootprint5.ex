defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Ayofootprint5 do
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
        x: 145,
        y: 120,
        dir: 0,
        sprite: 139,
        name: "AyoFootprint5",
        scope: :shared,
        trigger: {2, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: follow_trail(ctx)

  @impl true
  def on_talk(ctx), do: follow_trail(ctx)

  defp follow_trail(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 8 and Enum.random(1..3) < 2 do
      ctx
      |> mes("^3355FFYou find the same footprints")
      |> mes("in this place. It seems pretty")
      |> mes("dangerous, and you wonder why")
      |> mes("anyone would come here. The")
      |> mes("footprints continue towards")
      |> mes("the ^5C3317North^3355FF.^000000")
      |> set_char_var(:thai_find, 9)
      |> close()
    else
      ctx
    end
  end
end
