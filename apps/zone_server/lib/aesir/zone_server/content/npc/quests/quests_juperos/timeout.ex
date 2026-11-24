defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Timeout do
  @moduledoc """
  Controls the elevator challenge timeout.

  ## Behavior

  - Resets an empty elevator and expels players if the challenge times out.

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
    spawn: [
      %{
        map: "jupe_ele",
        x: 14,
        y: 6,
        dir: 1,
        sprite: 844,
        name: "TimeOut",
        scope: :shared,
        unique_name: "TimeOut#ufe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnEnable", ctx)
  end

  @impl true
  def on_event("OnEnable", ctx) do
    initnpctimer(ctx)
  end

  def on_event("OnDisable", ctx) do
    stopnpctimer(ctx)
  end

  def on_event("OnTimer59000", ctx) do
    if getmapusers(ctx, "jupe_ele") == 0 do
      ctx
      |> killmonsterall("jupe_ele")
      |> donpcevent("Guard-1#ufe::OnDisable")
      |> donpcevent("Guard-2#ufe::OnDisable")
      |> donpcevent("Guard-3#ufe::OnDisable")
      |> donpcevent("Guard-4#ufe::OnDisable")
      |> stopnpctimer()
      |> set_server_temp_var("JupeElevatorInUse2", 0)
      |> set_server_temp_var("JupeElevatorInUse", 0)
      |> disablenpc("Switch On#ufe")
      |> enablenpc("Switch#ufe")
    else
      ctx
    end
  end

  def on_event("OnTimer120000", ctx) do
    ctx
    |> killmonsterall("jupe_ele")
    |> donpcevent("Guard-1#ufe::OnDisable")
    |> donpcevent("Guard-2#ufe::OnDisable")
    |> donpcevent("Guard-3#ufe::OnDisable")
    |> donpcevent("Guard-4#ufe::OnDisable")
    |> mapannounce(
      "jupe_ele",
      "In the end, you can't even overcome your inner fear...",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer122000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele",
      "You have never encountered your inner fears, have you?",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer125000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele",
      "Did you expect this would be the end of the hallucination?",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer127000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele",
      "What if the voice you're hearing is also a hallucination?",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer129000", ctx) do
    mapannounce(ctx, "jupe_ele", "What if you're just dreaming all of this?", 1, "0xFF0000")
  end

  def on_event("OnTimer131000", ctx) do
    mapannounce(ctx, "jupe_ele", "What if the existence of this city is a lie?", 1, "0xFF0000")
  end

  def on_event("OnTimer133000", ctx) do
    mapannounce(ctx, "jupe_ele", "Are you even real?", 1, "0xFF0000")
  end

  def on_event("OnTimer134000", ctx) do
    on_event("OnTimer135000", ctx)
  end

  def on_event("OnTimer135000", ctx) do
    mapwarp(ctx, "jupe_ele", "jupe_gate", 49, 138)
  end

  def on_event("OnTimer142000", ctx) do
    ctx
    |> disablenpc("GuardEnd#ufe")
    |> disablenpc("4F Enter#ufe")
    |> donpcevent("TimeOut#ufe::OnDisable")
    |> set_server_temp_var("JupeElevatorInUse2", 0)
    |> set_server_temp_var("JupeElevatorInUse", 0)
    |> disablenpc("Switch On#ufe")
    |> enablenpc("Switch#ufe")
    |> stopnpctimer()
  end
end
