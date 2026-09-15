defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Guide73188 do
  @moduledoc """
  Shows Bonnie searching for something she misplaced.

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
        x: 73,
        y: 188,
        dir: 0,
        sprite: 862,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#lt2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx |> mes("[Bonnie]") |> mes("Oh no...") |> mes("Where did I put it?") |> close()
  end
end
