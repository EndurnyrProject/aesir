defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Signboard do
  @moduledoc """
  A notice prohibits Cute Pets except assistance animals.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_dun01",
        x: 163,
        y: 223,
        dir: 4,
        sprite: 857,
        name: "Signboard",
        scope: :shared,
        unique_name: "Signboard#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Notice]")
    |> mes("Cute Pets are prohibited")
    |> mes("in this area. (Cute Pets that")
    |> mes("provide special assistance")
    |> mes("to the visually impaired are")
    |> mes("exempt from this rule.)")
    |> close()
  end
end
