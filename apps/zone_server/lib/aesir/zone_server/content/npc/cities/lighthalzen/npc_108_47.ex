defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Npc10847 do
  @moduledoc """
  Describes a meticulously organized office desk.

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
        x: 108,
        y: 47,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#never"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis desk is very")
    |> mes("neat and well organized")
    |> mes("in comparison to the other")
    |> mes("desks you've seen in your")
    |> mes("time. You take a moment to")
    |> mes("fully marvel at its tidiness.^000000")
    |> close()
  end
end
