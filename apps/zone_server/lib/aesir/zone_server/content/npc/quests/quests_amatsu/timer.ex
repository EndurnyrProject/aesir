defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Timer do
  @moduledoc """
  Hidden countdown that limits the Momotaro event monster fight to six minutes.

  ## Behavior

  - Starts disabled; enabling it shows it and starts its timer.
  - Announces the start, then three and one minute remaining, then time over.
  - Briefly opens the return warp after time runs out, then closes it.
  - Finally resets the Assistant and stops its own timer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_test",
        x: 34,
        y: 18,
        dir: 0,
        sprite: -1,
        name: "Timer",
        scope: :shared,
        unique_name: "Timer#ama"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Timer#ama")
  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Timer#ama") |> initnpctimer()
  def on_event("OnDisable", ctx), do: stopnpctimer(ctx)

  def on_event("OnTimer1000", ctx) do
    announce(
      ctx,
      " The Timer has been activated. You have 6 minutes. Annihilate the monsters in time! "
    )
  end

  def on_event("OnTimer181000", ctx), do: announce(ctx, " 3 minutes left. ")
  def on_event("OnTimer301000", ctx), do: announce(ctx, " 1 minute left. ")
  def on_event("OnTimer361000", ctx), do: announce(ctx, "Beep- Beep- Beep- Time over.")
  def on_event("OnTimer361500", ctx), do: enablenpc(ctx, "backwarp#ama")
  def on_event("OnTimer362000", ctx), do: disablenpc(ctx, "backwarp#ama")

  def on_event("OnTimer362500", ctx) do
    ctx
    |> donpcevent("Assistant#ama::OnReset")
    |> donpcevent("Timer#ama::OnDisable")
  end

  @impl true
  def on_talk(ctx), do: disablenpc(ctx, "Timer#ama")

  defp announce(ctx, message), do: mapannounce(ctx, "ama_test", message, 1)
end
