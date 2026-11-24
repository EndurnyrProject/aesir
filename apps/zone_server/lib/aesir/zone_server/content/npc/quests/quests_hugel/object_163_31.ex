defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Object16331 do
  @moduledoc """
  A hidden scene describes an empty place.

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
        map: "que_hugel",
        x: 163,
        y: 31,
        dir: 0,
        sprite: 139,
        name: "object",
        scope: :shared,
        unique_name: "object#2",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFWhen you come back")
    |> mes("to your senses, you")
    |> mes("find that nothing is")
    |> mes("left in this place.^000000")
    |> close()
  end
end
