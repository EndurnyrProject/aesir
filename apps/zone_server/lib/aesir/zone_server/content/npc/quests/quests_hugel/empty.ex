defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Empty do
  @moduledoc """
  An empty room reveals that everyone has left.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 99,
        y: 90,
        dir: 0,
        sprite: 139,
        name: "Empty",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis place is empty.")
    |> mes("Everyone must")
    |> mes("have already left.^000000")
    |> close()
  end
end
