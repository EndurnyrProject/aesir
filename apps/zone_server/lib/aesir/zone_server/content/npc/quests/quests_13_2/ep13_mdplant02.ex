defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13Mdplant02 do
  @moduledoc """
  Marks a directional clue in the search for Terra.

  ## Behavior

  - Shows the clue after the player has found Terra's first trace.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild02",
        x: 122,
        y: 106,
        dir: 0,
        sprite: 844,
        name: "????",
        scope: :shared,
        unique_name: "????#ep13_mdplant02"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      if get_char_var(ctx, :ep13_mdrama, 0) > 2 do
        ctx
        |> cutin("ep13_plant01", 2)
        |> mes("Weeds are easy to find around here...")
        |> mes("A closer look reveals that there's one knotted stem...")
        |> mes("It looks like this is Terra's trace that Arc told me about.")
        |> next()
        |> mes("A knotted leaf is pointing ^4d4dff East^000000.")
        |> close()
      else
        ctx
        |> mes("Weeds are easy to find around here...")
        |> mes("There's nothing too special about it.")
        |> close()
      end

    cutin(ctx, "ep13_plant01", 255)
  end
end
