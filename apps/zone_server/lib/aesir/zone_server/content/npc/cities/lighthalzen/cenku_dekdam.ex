defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.CenkuDekdam do
  @moduledoc """
  Reflects on the wealth that defines Lighthalzen.

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
        map: "lhz_in01",
        x: 134,
        y: 45,
        dir: 3,
        sprite: 869,
        name: "Cenku Dekdam",
        scope: :shared,
        unique_name: "Cenku Dekdam#delic"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Cenku Dekdam]")
    |> mes("Man, if you were")
    |> mes("gonna take this whole")
    |> mes("city and then sell it, what")
    |> mes("do you think Lighthalzen's")
    |> mes("price tag would be, eh?")
    |> next()
    |> mes("[Cenku Dekdam]")
    |> mes("I mean, this city")
    |> mes("is basically just made")
    |> mes("of money. Money is what")
    |> mes("makes this city such a nice")
    |> mes("and pleasant place to live.")
    |> close()
  end
end
