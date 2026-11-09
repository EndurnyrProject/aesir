defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Izlude.CharfriIzlude do
  @moduledoc """
  Charfri, an Izlude resident who talks about Byalan Island.

  ## Behavior

  - Picks one of two topics per interaction: the town's seafront and the island
    boat, or the underwater dungeon said to lie beneath Byalan.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Nexon
    - Silentdragon
    - MasterOfMuppets
    - Silent
    - Evera
    - CAHTEXHuK
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 172,
        y: 215,
        dir: 4,
        sprite: 91,
        name: "Charfri",
        scope: :renewal,
        unique_name: "Charfri#izlude"
      },
      %{
        map: "izlude_a",
        x: 172,
        y: 215,
        dir: 4,
        sprite: 91,
        name: "Charfri",
        scope: :renewal,
        unique_name: "Charfri#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 172,
        y: 215,
        dir: 4,
        sprite: 91,
        name: "Charfri",
        scope: :renewal,
        unique_name: "Charfri#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 172,
        y: 215,
        dir: 4,
        sprite: 91,
        name: "Charfri",
        scope: :renewal,
        unique_name: "Charfri#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 172,
        y: 215,
        dir: 4,
        sprite: 91,
        name: "Charfri",
        scope: :renewal,
        unique_name: "Charfri#izlude_d"
      },
      %{
        map: "izlude",
        x: 135,
        y: 78,
        dir: 2,
        sprite: 91,
        name: "Charfri",
        scope: :pre_renewal,
        unique_name: "Charfri#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Charfri]")

    case :rand.uniform(2) - 1 do
      1 -> about_the_island(ctx)
      _ -> about_the_dungeon(ctx)
    end
  end

  defp about_the_island(ctx) do
    ctx
    |> mes(
      "Some people may think Izlude is just a satellite city of Prontera, and not really that important..."
    )
    |> next()
    |> mes("[Charfri]")
    |> mes(
      "But Izlude is a beautiful town right next to the ocean, as well as beautiful Byalan Island."
    )
    |> next()
    |> mes("[Charfri]")
    |> mes(
      "You'll have to board on a ship at the port to get to Byalan Island. There are dangerous dungeons on that island, so don't go snooping around just anywhere."
    )
    |> close()
  end

  defp about_the_dungeon(ctx) do
    ctx
    |> mes(
      "Though it is very beautiful, Byalan Island has a mysterious dungeon that extends deep under the sea."
    )
    |> next()
    |> mes("[Charfri]")
    |> mes(
      "People who've actually been there have said that if you go deep enough, the dungeon actually descends underwater."
    )
    |> next()
    |> mes("[Charfri]")
    |> mes(
      "Surprisingly, once you're underwater, you can breathe just like a fish. Maybe some kind of supernatural force is in effect."
    )
    |> next()
    |> mes("[Charfri]")
    |> mes("Ah...")
    |> mes(
      "The people who've seen the underwater view say it is so fantastic that they've kept dreaming of it ever since."
    )
    |> next()
    |> mes("[Charfri]")
    |> mes(
      "But unfortunately, the monsters are too strong for ordinary people to merely go sightseeing there. Still, just once, I'd like to go down there..."
    )
    |> close()
  end
end
