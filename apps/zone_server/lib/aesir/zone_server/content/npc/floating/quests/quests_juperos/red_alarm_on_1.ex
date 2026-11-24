defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.RedAlarmOn1 do
  @moduledoc """
  Alarm sequence of Juperos security checkpoint 1-3.

  ## Behavior

  - Broadcasts a series of warnings to the map, with warning sounds.
  - Releases the first guard wave (Monster1#1-3) partway through.

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
    spawn: [%{name: "Red Alarm On", unique_name: "Red Alarm On#1-3"}]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Red Alarm On#1-3")

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Red Alarm On#1-3") |> initnpctimer()

  def on_event("OnTimer1000", ctx) do
    mapannounce(ctx, "jupe_area1", "These security systems...", 1, "0xFF0000")
  end

  def on_event("OnTimer3000", ctx) do
    mapannounce(ctx, "jupe_area1", "They're not really for protection.", 1, "0xFF0000")
  end

  def on_event("OnTimer5000", ctx) do
    ctx
    |> mapannounce("jupe_area1", "It's sort of just a hobby to pass the time...", 1, "0xFF0000")
    |> donpcevent("Monster1#1-3::OnEnable")
  end

  def on_event("OnTimer7000", ctx) do
    mapannounce(
      ctx,
      "jupe_area1",
      "Being immortal, I have a lot of time on my hands...",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer8000", ctx), do: ctx |> disablenpc("Red Alarm On#1-3") |> stopnpctimer()

  @impl true
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
