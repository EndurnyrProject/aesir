defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Guardian do
  @moduledoc """
  Describes guardians undergoing repairs.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thor_camp",
        x: 181,
        y: 231,
        dir: 0,
        sprite: 111,
        name: "Guardian",
        scope: :shared,
        unique_name: "Guardian#vol_7"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThere are many guardians")
    |> mes("here in different stages")
    |> mes("of disassembly. It looks")
    |> mes("like they're all in the")
    |> mes("middle of being repaired.^000000")
    |> close()
  end
end
