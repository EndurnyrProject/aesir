defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.DrunkenMan do
  @moduledoc """
  Shows Enku drinking after being left by his partner.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in03",
        x: 189,
        y: 87,
        dir: 5,
        sprite: 869,
        name: "Drunken Man",
        scope: :shared,
        unique_name: "Drunken Man#amano01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Enku]")
    |> mes("*Sob* I just got")
    |> mes("dumped! Yeah, I thought")
    |> mes("we were gonna get married,")
    |> mes("but obviously I was wrong!")
    |> mes("Damn it Sheryline! I loved you!")
    |> next()
    |> mes("[Enku]")
    |> mes("I usually don't care for")
    |> mes("drinking, especially stuff")
    |> mes("like gin or rum, but today,")
    |> mes("this stuff tastes just like")
    |> mes("my misery. This is all the")
    |> mes("comfort I need, you hear?!")
    |> close()
  end
end
