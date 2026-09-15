defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.APartTimer2677 do
  @moduledoc """
  Describes a part-time worker absorbed in organizing the expedition office.

  ## Credits

  - Original from rAthena, authors and Contributors
    - vicious_pucca
    - Poki#3
    - erKURITA
    - Munin

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 26,
        y: 77,
        dir: 4,
        sprite: 50,
        name: "A Part-Timer",
        scope: :shared,
        unique_name: "A Part-Timer#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis part-timer is")
    |> mes("completely engrossed")
    |> mes("in his task of organizing")
    |> mes("files and books.^000000")
    |> close()
  end
end
