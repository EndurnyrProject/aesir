defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.IceBoss do
  @moduledoc """
  Announces the awakening of the ice cave boss.

  ## Behavior

  - Runs timed announcements before starting the boss encounter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ice_dun03",
        x: 1,
        y: 173,
        dir: 5,
        sprite: -1,
        name: "ice_boss",
        scope: :shared,
        unique_name: "ice_boss#broad"
      }
    ]

  @impl true
  def on_event("OnStop", ctx), do: handle_stop(ctx)
  def on_event("OnStart", ctx), do: handle_start(ctx)
  def on_event("OnTimer2000", ctx), do: handle_timer2000(ctx)
  def on_event("OnTimer8000", ctx), do: handle_timer8000(ctx)
  def on_event("OnTimer10000", ctx), do: handle_timer10000(ctx)
  def on_event("OnTimer13000", ctx), do: handle_timer13000(ctx)
  def on_event("OnTimer16000", ctx), do: handle_timer16000(ctx)
  def on_event("OnTimer19000", ctx), do: handle_timer19000(ctx)
  def on_event("OnTimer21000", ctx), do: handle_timer21000(ctx)
  @impl true
  def on_talk(ctx) do
    handle_stop(ctx)
  end

  defp handle_stop(ctx) do
    stopnpctimer(ctx)
  end

  defp handle_start(ctx) do
    initnpctimer(ctx)
  end

  defp handle_timer2000(ctx) do
    mapannounce(ctx, "ice_dun03", "Someone has put out Thor's flames... Infidel!", 1, 16_737_843)
  end

  defp handle_timer8000(ctx) do
    mapannounce(
      ctx,
      "ice_dun03",
      "I, Ktullanux, must protect and preserve Thor's fierce flames...",
      1,
      16_737_843
    )
  end

  defp handle_timer10000(ctx) do
    mapannounce(ctx, "ice_dun03", "As the master of this cave, I vow vengeance!", 1, 16_737_843)
  end

  defp handle_timer13000(ctx) do
    mapannounce(ctx, "ice_dun03", "Only a human would be so foolhardy....", 1, 16_737_843)
  end

  defp handle_timer16000(ctx) do
    mapannounce(ctx, "ice_dun03", "Your curiosity will cost you, human.", 1, 16_737_843)
  end

  defp handle_timer19000(ctx) do
    mapannounce(
      ctx,
      "ice_dun03",
      "Prepare yourself for a freezing realm of pain which you cannot possibly imagine!",
      1,
      16_737_843
    )
  end

  defp handle_timer21000(ctx) do
    ctx |> stopnpctimer() |> donpcevent("ice_boss#on::OnStart")
  end
end
