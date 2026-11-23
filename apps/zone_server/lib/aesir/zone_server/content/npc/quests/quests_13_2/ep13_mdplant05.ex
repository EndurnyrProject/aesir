defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13Mdplant05 do
  @moduledoc """
  Marks a further trail in the search for Terra.

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
        map: "spl_fild01",
        x: 341,
        y: 109,
        dir: 0,
        sprite: 844,
        name: "????",
        scope: :shared,
        unique_name: "????#ep13_mdplant05"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_mdrama, 0) == 4 ->
        ctx
        |> mes("There's evidence that there was a fight here too.")
        |> mes("These footsteps can't be a Laphine's...")
        |> next()
        |> mes("There are footprints that lead to^4d4dff the Root of a huge tree^000000.")
        |> set_char_var(:ep13_mdrama, 5)
        |> close()

      get_char_var(ctx, :ep13_mdrama, 0) > 4 ->
        ctx
        |> mes("There are footprints that lead to^4d4dff the Root of a huge tree^000000.")
        |> close()

      true ->
        ctx
        |> mes("There are footprints here that seem to be leading towards something.")
        |> close()
    end
  end
end
