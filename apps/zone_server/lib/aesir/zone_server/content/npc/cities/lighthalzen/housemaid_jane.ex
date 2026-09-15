defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.HousemaidJane do
  @moduledoc """
  Describes Jane's difficulty keeping an enormous house clean.

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
        x: 129,
        y: 22,
        dir: 7,
        sprite: 850,
        name: "Housemaid Jane",
        scope: :shared,
        unique_name: "Housemaid Jane#li_house1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Housemaid Jane]")
    |> mes("This house is enormous...")
    |> mes("It's clearly much too big")
    |> mes("for a regularly sized family.")
    |> mes("And it takes me forever to")
    |> mes("make sure that it stays clean!")
    |> next()
    |> mes("[Housemaid Jane]")
    |> mes("It's not easy keeping")
    |> mes("things neat and tidy when")
    |> mes("you're responsible for acres")
    |> mes("of indoor living space. Being")
    |> mes("a maid can be pretty hard...")
    |> close()
  end
end
