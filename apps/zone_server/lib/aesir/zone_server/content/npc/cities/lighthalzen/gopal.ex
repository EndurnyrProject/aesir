defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Gopal do
  @moduledoc """
  Shares Gopal's ambition to build a major company.

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
        x: 25,
        y: 105,
        dir: 5,
        sprite: 869,
        name: "Gopal",
        scope: :shared,
        unique_name: "Gopal#zen4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Gopal]")
    |> mes("Granny may be happy")
    |> mes("just sitting around and")
    |> mes("enjoying the peaceful life,")
    |> mes("but I'm not! I'm too young")
    |> mes("to just lay down and let")
    |> mes("these days just pass by!")
    |> next()
    |> mes("[Gopal]")
    |> mes("I wanna make something")
    |> mes("of myself. Maybe someday,")
    |> mes("I'll found a company as big")
    |> mes("as the Rekenber Corporation!")
    |> close()
  end
end
