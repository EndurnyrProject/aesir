defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Kiehlroom do
  @moduledoc """
  The Kiehl encounter controller tracks defeated enemies and resets the room.

  ## Behavior

  - Reveals the original Kiehl after five minion deaths and records the boss defeat.
  - Resets the trap, evacuates occupants, clears monsters, hides agents, and releases the room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "kh_kiehl02", x: 1, y: 1, dir: 0, sprite: -1, name: "KiehlRoom", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnKiehlMobDead", ctx) do
    ctx = set_npc_var(ctx, "KHKilled", get_npc_var(ctx, "KHKilled", 0) + 1)

    if get_npc_var(ctx, "KHKilled", 0) == 5 do
      hideoffnpc(ctx, "Kiehl#Original")
    else
      ctx
    end
  end

  def on_event("OnKiehlDead", ctx) do
    ctx |> set_npc_var("KHKilledBoss", 1) |> hideoffnpc("Kiehl#Original")
  end

  def on_event("OnReset", ctx) do
    ctx = donpcevent(ctx, "Kiehl_Room_Trap::OnGlobalTimerOff")

    ctx =
      if getmapusers(ctx, "kh_kiehl02") > 0 do
        mapwarp(ctx, "kh_kiehl02", "lighthalzen", 192, 200)
      else
        ctx
      end

    ctx
    |> killmonsterall("kh_kiehl02")
    |> disablenpc("Kiehl_Room_Exit")
    |> hideonnpc("Mitchell#KiehlRoom")
    |> hideonnpc("Agent#KHAgent1")
    |> hideonnpc("Agent#KHAgent2")
    |> hideonnpc("Agent#KHAgent3")
    |> hideonnpc("Agent#KHAgent4")
    |> hideonnpc("Kiehl#Copy")
    |> hideoffnpc("Kiehl#Original")
    |> set_npc_var("KHKilledBoss", 0)
    |> set_npc_var("KHKilled", 0)
    |> set_npc_var_of("KHTrapSprung", "Kiehl_Room_Trap", 0)
    |> set_server_temp_var("KHQuestBusy", 0)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
