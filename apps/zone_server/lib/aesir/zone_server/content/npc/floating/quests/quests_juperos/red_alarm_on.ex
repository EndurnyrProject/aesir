defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.RedAlarmOn do
  @moduledoc """
  Alarm sequence of Juperos security checkpoint 1-1.

  ## Behavior

  - Broadcasts a series of warnings to the map, with warning sounds.
  - Releases the first guard wave (Monster1#1-1) partway through.

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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Red Alarm On#1-1")

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Red Alarm On#1-1") |> initnpctimer()

  def on_event("OnTimer1000", ctx) do
    mapannounce(ctx, "jupe_area1", "Those of you who have come here...", 1, "0xFF0000")
  end

  def on_event("OnTimer3000", ctx) do
    ctx
    |> mapannounce("jupe_area1", "I do not intend to stop you.", 1, "0xFF0000")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area1")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area1")
  end

  def on_event("OnTimer5000", ctx) do
    ctx
    |> mapannounce(
      "jupe_area1",
      "But I assume you are prepared for a few obstacles...",
      1,
      "0xFF0000"
    )
    |> donpcevent("Monster1#1-1::OnEnable")
  end

  def on_event("OnTimer7000", ctx) do
    mapannounce(
      ctx,
      "jupe_area1",
      "After all, you are venturing through a forbidden area!",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer8000", ctx) do
    ctx
    |> disablenpc("Red Alarm On#1-1")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area1")
    |> soundeffectall("jupe_warning.wav", 0, "jupe_area1")
    |> stopnpctimer()
  end

  @impl true
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
