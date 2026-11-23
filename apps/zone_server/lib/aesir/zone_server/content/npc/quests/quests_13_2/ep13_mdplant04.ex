defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13Mdplant04 do
  @moduledoc """
  Marks footprints in the search for Terra.

  ## Behavior

  - Reveals the trail and advances the quest at the appropriate stage.

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
        x: 328,
        y: 323,
        dir: 0,
        sprite: 844,
        name: "????",
        scope: :shared,
        unique_name: "????#ep13_mdplant04"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_mdrama, 0) == 3 ->
        ctx
        |> mes("There are footprints here as well as signs that someone has fallen.")
        |> mes("It looks like someone was fighting here?")
        |> mes("But who?")
        |> next()
        |> mes("There are footprints heading ^4d4dffNorth^000000.")
        |> set_char_var(:ep13_mdrama, 4)
        |> close()

      get_char_var(ctx, :ep13_mdrama, 0) > 3 ->
        ctx
        |> mes("Someone must have had a fight here.")
        |> mes("There are footprints heading ^4d4dffNorth^000000.")
        |> close()

      true ->
        ctx
        |> mes("There are footprints here that seem to be leading towards something.")
        |> close()
    end
  end
end
