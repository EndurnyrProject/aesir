defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.YoungMan do
  @moduledoc """
  Wonders whether filling himself with air could make him float.

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
      %{map: "hugel", x: 189, y: 143, dir: 5, sprite: 898, name: "Young Man", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Young Man]")
    |> mes("Huh. So that giant")
    |> mes("air pouch can make")
    |> mes("people float in midair?")
    |> mes("Would filling my tummy")
    |> mes("with air work the same way?")
    |> close()
  end
end
