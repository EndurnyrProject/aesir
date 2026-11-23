defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Letter do
  @moduledoc """
  An explorer’s letter describes the stranded Turtle Island expedition.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta_in",
        x: 18,
        y: 102,
        dir: 4,
        sprite: 111,
        name: "Letter",
        scope: :shared,
        unique_name: "Letter#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Explorer's Letter]")
    |> mes("- O / X / XOVX -")
    |> mes("If you find this letter, please don't disregard what you have read.")
    |> next()
    |> mes("[Explorer's Letter]")
    |> mes("Although we have found Turtle Island, it seems our expedition will fail.")
    |> next()
    |> mes("[Explorer's Letter]")
    |> mes(
      "Only half of our crew is left, and we only have enough food for ten more days. Our condition is truly grave."
    )
    |> next()
    |> mes("[Explorer's Letter]")
    |> mes(
      "This damn island must be cursed. There's nothing to eat and we're so close to starving!"
    )
    |> next()
    |> mes("[Explorer's Letter]")
    |> mes("If we don't get help or find Alberta soon...")
    |> mes("We'll...")
    |> close()
  end
end
