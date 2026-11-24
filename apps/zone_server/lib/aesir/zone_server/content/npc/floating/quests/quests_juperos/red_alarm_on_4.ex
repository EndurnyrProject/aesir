defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsJuperos.RedAlarmOn4 do
  @moduledoc """
  Alarm sequence of Juperos security checkpoint 2-2.

  ## Behavior

  - Broadcasts a series of warnings to the map, with warning sounds.
  - Releases the first guard wave (Monster1#2-2) partway through.

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
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Red Alarm On#2-2")

  def on_event("OnEnable", ctx), do: ctx |> enablenpc("Red Alarm On#2-2") |> initnpctimer()

  def on_event("OnTimer1000", ctx) do
    mapannounce(ctx, "jupe_area2", "Come on, come on!", 1, "0xFF0000")
  end

  def on_event("OnTimer3000", ctx) do
    mapannounce(ctx, "jupe_area2", "Yes. Run... Right into my hands!", 1, "0xFF0000")
  end

  def on_event("OnTimer5000", ctx) do
    ctx
    |> mapannounce("jupe_area2", "Do you want to know who I am?", 1, "0xFF0000")
    |> donpcevent("Monster1#2-2::OnEnable")
  end

  def on_event("OnTimer7000", ctx) do
    mapannounce(
      ctx,
      "jupe_area2",
      "You will know, once you defeat all of my minions!",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer8000", ctx), do: ctx |> disablenpc("Red Alarm On#2-2") |> stopnpctimer()

  @impl true
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
