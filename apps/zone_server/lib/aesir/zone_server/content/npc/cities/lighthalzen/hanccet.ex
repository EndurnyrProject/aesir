defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Hanccet do
  @moduledoc """
  Shows Hanccet searching for his sister during a game.

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
        x: 28,
        y: 33,
        dir: 7,
        sprite: 706,
        name: "Hanccet",
        scope: :shared,
        unique_name: "Hanccet#li_party"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hanccet]")
    |> mes("Man... I hate being ''it!''")
    |> mes("I'm horrible at this game!")
    |> mes("Alright, okay, if I were my")
    |> mes("sister Luccet, where would")
    |> mes("I think I would not look for")
    |> mes("me? Of course...! The sewers!")
    |> close()
  end
end
