defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Guardend do
  @moduledoc """
  Concludes the elevator guard encounter.

  ## Behavior

  - Opens the core entrance, transfers remaining players, and resets the switch.

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
        x: 19,
        y: 6,
        dir: 1,
        sprite: 844,
        name: "GuardEnd",
        scope: :shared,
        unique_name: "GuardEnd#ufe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "GuardEnd#ufe")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("GuardEnd#ufe") |> donpcevent("TimeOut#ufe::OnDisable") |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("GuardEnd#ufe") |> stopnpctimer()
  end

  def on_event("OnTimer2000", ctx) do
    mapannounce(ctx, "jupe_ele", "I am not going to tell you anything.", 1, "0x66FF00")
  end

  def on_event("OnTimer5000", ctx) do
    mapannounce(ctx, "jupe_ele", "My city, my people are now but a memory.", 1, "0x66FF00")
  end

  def on_event("OnTimer8000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele",
      "Everything was a mistake. We were not supposed to be here.",
      1,
      "0x66FF00"
    )
  end

  def on_event("OnTimer11000", ctx) do
    mapannounce(ctx, "jupe_ele", "Is this a place where humans are forbidden?", 1, "0x66FF00")
  end

  def on_event("OnTimer12000", ctx) do
    ctx
    |> mapannounce(
      "jupe_ele",
      "You want to know, don't you? Go ahead... Go deeper.",
      1,
      "0x66FF00"
    )
    |> enablenpc("4F Enter#ufe")
  end

  def on_event("OnTimer22000", ctx) do
    ctx
    |> mapannounce(
      "jupe_ele",
      "It's not real anyway. All of it's safe, it can't hurt you...",
      1,
      "0x66FF00"
    )
    |> soundeffectall("earth_quake.wav", 0)
    |> disablenpc("4F Enter#ufe")
  end

  def on_event("OnTimer24000", ctx) do
    mapwarp(ctx, "jupe_ele", "jupe_core", 150, 286)
  end

  def on_event("OnTimer25000", ctx) do
    mapwarp(ctx, "jupe_ele", "jupe_core", 151, 286)
  end

  def on_event("OnTimer26000", ctx) do
    ctx
    |> set_server_temp_var("JupeElevatorInUse2", 0)
    |> set_server_temp_var("JupeElevatorInUse", 0)
    |> disablenpc("Switch On#ufe")
    |> enablenpc("Switch#ufe")
    |> donpcevent("GuardEnd#ufe::OnDisable")
  end
end
