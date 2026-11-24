defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.RedAlarmOn6 do
  @moduledoc """
  Alarm sequence of Juperos security checkpoint 2-4.

  ## Behavior

  - Broadcasts a series of warnings to the map, with warning sounds.
  - Releases the first guard wave (Monster1#2-4) partway through.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{name: "Red Alarm On", unique_name: "Red Alarm On#2-4"}]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Red Alarm On#2-4")

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Red Alarm On#2-4") |> initnpctimer()

  def on_event("OnTimer1000", ctx) do
    mapannounce(
      ctx,
      "jupe_area2",
      "I've been waiting for someone strong enough to compete with me.",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer3000", ctx) do
    mapannounce(
      ctx,
      "jupe_area2",
      "If you hear this, I wish you will be the one...",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer5000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "Perhaps, a mere shadow of my former self...", 1, "0xFF0000")
    |> donpcevent("Monster1#2-4::OnEnable")
  end

  def on_event("OnTimer7000", ctx) do
    mapannounce(ctx, "jupe_area2", "Is somewhere down here, wandering...", 1, "0xFF0000")
  end

  def on_event("OnTimer8000", ctx), do: ctx |> stopnpctimer() |> disablenpc("Red Alarm On#2-4")

  @impl true
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
