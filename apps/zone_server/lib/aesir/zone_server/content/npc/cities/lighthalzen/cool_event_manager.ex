defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.CoolEventManager do
  @moduledoc """
  Shows Baoto considering stricter management of his employees.

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
        map: "lhz_in02",
        x: 110,
        y: 286,
        dir: 5,
        sprite: 853,
        name: "Cool Event Manager",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Baoto]")
    |> mes("Hmmm...")
    |> mes("The employees seem")
    |> mes("to be having too much")
    |> mes("fun amongst themselves")
    |> mes("recently. This does not")
    |> mes("bode well at all...")
    |> next()
    |> mes("[Baoto]")
    |> mes("It looks like I'm")
    |> mes("just going to have to")
    |> mes("start cracking that whip")
    |> mes("more often and much")
    |> mes("harder. Ha ha ha ha!")
    |> close()
  end
end
