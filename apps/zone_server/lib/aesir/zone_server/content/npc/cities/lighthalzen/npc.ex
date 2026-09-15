defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Npc do
  @moduledoc """
  Describes a cluttered desk and its family portrait.

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
        y: 53,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#horri"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis is simply a pile")
    |> mes("of files, a smattering of")
    |> mes("books and a family portrait.^000000")
    |> close()
  end
end
