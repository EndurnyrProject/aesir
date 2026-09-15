defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Gracie do
  @moduledoc """
  Praises the comfort of the bank despite its unavailable services.

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
        x: 31,
        y: 33,
        dir: 3,
        sprite: 863,
        name: "Gracie",
        scope: :shared,
        unique_name: "Gracie#5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Gracie]")
    |> mes("Oh, it's so comfortable")
    |> mes("in here~ Though, why are")
    |> mes("we inside the bank when")
    |> mes("the bank services aren't even")
    |> mes("working? Yes, we're standing,")
    |> mes("but we're doing it in comfort.")
    |> next()
    |> mes("[Gracie]")
    |> mes("In fact, it's so")
    |> mes("comfortable here,")
    |> mes("I think I'll refuse to leave.")
    |> mes("Though, I'm willing to change")
    |> mes("my mind if you can find a place")
    |> mes("that's even more comfortable.")
    |> close()
  end
end
