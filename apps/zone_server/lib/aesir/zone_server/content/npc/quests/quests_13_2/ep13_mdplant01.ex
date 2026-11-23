defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13Mdplant01 do
  @moduledoc """
  Marks the first clue in the search for Terra.

  ## Behavior

  - Reveals a directional clue and advances the quest at the appropriate stage.

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
        x: 45,
        y: 214,
        dir: 0,
        sprite: 844,
        name: "????",
        scope: :shared,
        unique_name: "????#ep13_mdplant01"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      if get_char_var(ctx, :ep13_mdrama, 0) == 2 do
        ctx
        |> cutin("ep13_plant01", 2)
        |> mes("Weeds are easy to find around here...")
        |> mes("A closer look reveals that there's one knotted stem...")
        |> mes("It looks like this is Terra's trace that Arc told me about.")
        |> next()
        |> mes("A knotted leaf is pointing toward the^4d4dff Southern^000000 direction.")
        |> set_char_var(:ep13_mdrama, 3)
        |> changequest(7056, 7057)
        |> close()
      else
        if get_char_var(ctx, :ep13_mdrama, 0) > 2 do
          ctx
          |> mes("This is a marking Terra left to remember the way back home.")
          |> mes("A knotted leaf is pointing^4d4dff South^000000.")
          |> close()
        else
          ctx
          |> mes("Weeds are easy to find around here...")
          |> mes("There's nothing too special about it.")
          |> close()
        end
      end

    cutin(ctx, "ep13_plant01", 255)
  end
end
