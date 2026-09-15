defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Annette do
  @moduledoc """
  Describes Annette's dream of holding a memorable wedding in the Rekenber Banquet Hall.

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
        x: 21,
        y: 50,
        dir: 7,
        sprite: 91,
        name: "Annette",
        scope: :shared,
        unique_name: "Annette#li_party"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Annette]")
    |> mes("I've heard that the")
    |> mes("Rekenber Banquet Hall")
    |> mes("is also used to hold weddings.")
    |> mes("That must be so wonderful~")
    |> next()
    |> mes("[Annette]")
    |> mes("Even if it is more expensive,")
    |> mes("I'd want to have my wedding")
    |> mes("here. Marriage is only once")
    |> mes("in a lifetime, ideally, so I'd")
    |> mes("want to make mine the most")
    |> mes("memorable experience.")
    |> close()
  end
end
