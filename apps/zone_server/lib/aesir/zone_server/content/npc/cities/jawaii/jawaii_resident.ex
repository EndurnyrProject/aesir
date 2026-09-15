defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.JawaiiResident do
  @moduledoc """
  Describes Heart Island to visitors in Jawaii.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 220,
        y: 235,
        dir: 3,
        sprite: 724,
        name: "Jawaii Resident",
        scope: :shared,
        unique_name: "Jawaii Resident#heart"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Jawa Jawa]")
    |> mes("You know what's")
    |> mes("the most beautiful")
    |> mes("place in Jawaii?")
    |> next()
    |> mes("[Jawa Jawa]")
    |> mes(
      "It's 'Heart Island,' which is just a little north of here. The water surrounding Heart Island is not that deep, so you can just walk across if you're careful."
    )
    |> next()
    |> mes("[Jawa Jawa]")
    |> mes("That's the best place to share an intimate moment with the person")
    |> mes("you love. It's perfectly secluded and such a beautiful area.")
    |> next()
    |> mes("[Jawa Jawa]")
    |> mes("Of course, it's probably not")
    |> mes("a good idea to go there by")
    |> mes("yourself if you're single.")
    |> mes("You'd look like such")
    |> mes("a pathetic loser!")
    |> close()
  end
end
