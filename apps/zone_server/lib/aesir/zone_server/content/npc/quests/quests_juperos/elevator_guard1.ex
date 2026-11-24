defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.ElevatorGuard1 do
  @moduledoc """
  Runs the elevator reception guard encounter.

  ## Behavior

  - Spawns guards and starts the elevator when they are defeated.
  - Resets the switch and expels players when time runs out.

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
        map: "jupe_ele_r",
        x: 10,
        y: 50,
        dir: 0,
        sprite: -1,
        name: "Elevator Guard1",
        scope: :shared,
        unique_name: "Elevator Guard1#ufe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Elevator Guard1#ufe")
  end

  def on_event("OnEnable", ctx) do
    ctx |> set_npc_var("MyMobs", 9) |> enablenpc("Elevator Guard1#ufe") |> initnpctimer()
  end

  def on_event("OnTimer1000", ctx) do
    summon_mob(ctx,
      mob_id: 1669,
      map: "jupe_ele_r",
      at: {44, 99},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer1200", ctx) do
    summon_mob(ctx,
      mob_id: 1675,
      map: "jupe_ele_r",
      at: {55, 99},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer1400", ctx) do
    summon_mob(ctx,
      mob_id: 1683,
      map: "jupe_ele_r",
      at: {45, 84},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer1600", ctx) do
    summon_mob(ctx,
      mob_id: 1675,
      map: "jupe_ele_r",
      at: {54, 84},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer1800", ctx) do
    summon_mob(ctx,
      mob_id: 1669,
      map: "jupe_ele_r",
      at: {45, 99},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer2000", ctx) do
    summon_mob(ctx,
      mob_id: 1683,
      map: "jupe_ele_r",
      at: {54, 99},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer2200", ctx) do
    summon_mob(ctx,
      mob_id: 1669,
      map: "jupe_ele_r",
      at: {48, 84},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer2400", ctx) do
    summon_mob(ctx,
      mob_id: 1683,
      map: "jupe_ele_r",
      at: {52, 84},
      name: "Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer2600", ctx) do
    summon_mob(ctx,
      mob_id: 1684,
      map: "jupe_ele_r",
      at: {50, 84},
      name: "Chief Guard",
      event: "Elevator Guard1#ufe::OnMyMobDead"
    )
  end

  def on_event("OnTimer120000", ctx) do
    ctx
    |> mapannounce(
      "jupe_ele_r",
      "It is disappointing to see that you are too weak to even defeat a hallucination...",
      1,
      "0x66FF00"
    )
    |> enablenpc("Switch#ufe")
    |> disablenpc("Switch On#ufe")
    |> donpcevent("Annihilation#ufe::OnEnable")
    |> set_server_temp_var("JupeElevatorInUse", 0)
  end

  def on_event("OnTimer120005", ctx) do
    ctx |> killmonster("jupe_ele_r", "Elevator Guard1#ufe::OnMyMobDead") |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx |> donpcevent("Elevator Safety#ufe::OnEnable") |> stopnpctimer()
    else
      ctx
    end
  end
end
