defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.AFile170109 do
  @moduledoc """
  A file shelf in the Prontera library where the 3rd Platoon Records of the Megingjard Seal
  quest can be found.

  ## Behavior

  - While the player is searching the library, each look through the shelf has a 4 in 10
    chance to advance the search.
  - Once the records are found, the shelf only repeats that they were found.
  - Before or after the search, the librarian keeps the player away from the section.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 170,
        y: 109,
        dir: 0,
        sprite: 111,
        name: "A File",
        scope: :shared,
        unique_name: "A File#megin2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    eremes = get_char_var(ctx, :god_eremes, 0)

    cond do
      eremes == 12 ->
        ctx
        |> mes("You have found ^0000FFThe 3rd Platoon Records^000000!")
        |> close()

      eremes > 6 and eremes < 12 ->
        search_shelf(ctx, eremes)

      true ->
        ctx
        |> mes("[Librarian Jekan]")
        |> mes("W-wait...!")
        |> mes("That section")
        |> mes("is off limits!")
        |> close()
    end
  end

  defp search_shelf(ctx, eremes) do
    found? = Enum.random(1..10) > 6

    ctx =
      mes(
        ctx,
        "^3355FFYou see a shelf filled with many files. You begin searching through them, one by one.^000000"
      )

    if found? do
      ctx |> set_char_var(:god_eremes, eremes + 1) |> close()
    else
      close(ctx)
    end
  end
end
