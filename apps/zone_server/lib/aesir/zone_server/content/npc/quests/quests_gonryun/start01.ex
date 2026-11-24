defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Start01 do
  @moduledoc """
  Hidden controller of the Broken Sword blade search on its dungeon floor.

  ## Behavior

  - At startup, waits 10 seconds and then activates one of the floor's 5 blade traces
    at random.
  - Activates another random trace whenever the active trace expires or its blade piece is
    revealed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_dun01",
        x: 148,
        y: 156,
        dir: 0,
        sprite: -1,
        name: "start01",
        scope: :shared,
        unique_name: "start01#gnbs"
      }
    ]

  @impl true
  def on_talk(ctx), do: start_search(ctx)

  @impl true
  def on_event("OnInit", ctx), do: start_search(ctx)
  def on_event("OnCommandOn", ctx), do: activate_random_trace(ctx)

  defp start_search(ctx) do
    ctx |> sleep(10_000) |> activate_random_trace()
  end

  defp activate_random_trace(ctx) do
    donpcevent(ctx, "trace1-#{Enum.random(1..5)}#gnbs::OnCommandOn")
  end
end
