defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.M2DunIn do
  @moduledoc """
  The entrance to the second level of the Ayothaya dungeon.

  ## Behavior

  - Admits players with sufficient quest progress and holy thread at a random entrance.

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
        x: 24,
        y: 283,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #2_dun_in"
      }
    ]

  @holy_thread 7287

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ayodunquest, 0) > 10 and count_item(ctx, @holy_thread) > 0 do
      ctx =
        ctx
        |> mes("^3355FFThe holy threads")
        |> mes("emanate a powerful sense")
        |> mes("of safety and security.")
        |> mes("With the protection of")
        |> mes("holiness, you begin your")
        |> mes("descent into the 2nd level.^000000.")
        |> close()

      if Enum.random(1..10) > 5 do
        warp(ctx, "ayo_dun02", 23, 26)
      else
        warp(ctx, "ayo_dun02", 275, 26)
      end
    else
      ctx
      |> mes(
        "^3355FFYou find what seems to be the entrance to the 2nd level. However, you are filled with an overwhelming sense of dread. Somehow, you can't bring yourself to go down...^000000"
      )
      |> close()
    end
  end
end
