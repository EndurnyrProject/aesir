defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Guard4 do
  @moduledoc """
  Runs the final elevator guard wave.

  ## Behavior

  - Spawns guards and completes the encounter once all waves are defeated.

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
        x: 18,
        y: 6,
        dir: 1,
        sprite: 844,
        name: "Guard-4",
        scope: :shared,
        unique_name: "Guard-4#ufe"
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

  def on_event("OnTimer2000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele",
      "Do not forget. That which limits you is nothing but yourself.",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer5000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele",
      "Nothing is what you fear and you have nothing to fear...",
      1,
      "0xFF0000"
    )
  end

  def on_event("OnTimer8000", ctx) do
    ctx
    |> set_npc_var("MyMobs", 8)
    |> summon_mob(
      mob_id: 1684,
      map: "jupe_ele",
      at: {48, 44},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1669,
      map: "jupe_ele",
      at: {45, 42},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1684,
      map: "jupe_ele",
      at: {38, 42},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1669,
      map: "jupe_ele",
      at: {35, 44},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1675,
      map: "jupe_ele",
      at: {35, 51},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1669,
      map: "jupe_ele",
      at: {38, 53},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1683,
      map: "jupe_ele",
      at: {45, 53},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1675,
      map: "jupe_ele",
      at: {48, 51},
      name: "Guard",
      event: "Guard-4#ufe::OnMyMobDead"
    )
    |> set_server_temp_var("JupeElevatorInUse2", 4)
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 and
         get_npc_var_of(ctx, "MyMobs", "Guard-1#ufe", 0) < 1 and
         get_npc_var_of(ctx, "MyMobs", "Guard-2#ufe", 0) < 1 and
         get_npc_var_of(ctx, "MyMobs", "Guard-3#ufe", 0) < 1 do
      ctx |> donpcevent("GuardEnd#ufe::OnEnable") |> stopnpctimer()
    else
      ctx
    end
  end
end
