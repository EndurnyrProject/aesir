defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Alex155108 do
  @moduledoc """
  A locked door blocks the way.

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
        x: 155,
        y: 108,
        dir: 0,
        sprite: 45,
        name: "alex",
        scope: :shared,
        unique_name: "alex#warp4",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)
  @impl true
  def on_talk(ctx) do
    ctx |> mes("^3355FFThe door is locked.^000000") |> close()
  end
end
