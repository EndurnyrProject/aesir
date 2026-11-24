defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Guard1 do
  @moduledoc """
  Runs the first elevator guard wave.

  ## Behavior

  - Spawns guards and advances the encounter on defeat or timeout.

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
        x: 15,
        y: 6,
        dir: 1,
        sprite: 844,
        name: "Guard-1",
        scope: :shared,
        unique_name: "Guard-1#ufe"
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
    mapannounce(ctx, "jupe_ele", "I admire your patience.", 1, "0xFF0000")
  end

  def on_event("OnTimer5000", ctx) do
    mapannounce(ctx, "jupe_ele", "Let's see if everything you have experienced", 1, "0xFF0000")
  end

  def on_event("OnTimer8000", ctx) do
    mapannounce(ctx, "jupe_ele", "were traps for intruders...", 1, "0xFF0000")
  end

  def on_event("OnTimer12000", ctx) do
    ctx
    |> set_npc_var("MyMobs", 8)
    |> summon_mob(
      mob_id: 1675,
      map: "jupe_ele",
      at: {48, 44},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1669,
      map: "jupe_ele",
      at: {45, 42},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1675,
      map: "jupe_ele",
      at: {38, 42},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1669,
      map: "jupe_ele",
      at: {35, 44},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1675,
      map: "jupe_ele",
      at: {35, 51},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1669,
      map: "jupe_ele",
      at: {38, 53},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1675,
      map: "jupe_ele",
      at: {45, 53},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1669,
      map: "jupe_ele",
      at: {48, 51},
      name: "Guard",
      event: "Guard-1#ufe::OnMyMobDead"
    )
    |> set_server_temp_var("JupeElevatorInUse2", 1)
  end

  def on_event("OnTimer30000", ctx) do
    if get_server_temp_var(ctx, "JupeElevatorInUse2", 0) == 1 do
      ctx |> donpcevent("Guard-2#ufe::OnEnable") |> stopnpctimer()
    else
      ctx
    end
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      cond do
        get_server_temp_var(ctx, "JupeElevatorInUse2", 0) == 1 ->
          ctx |> donpcevent("Guard-2#ufe::OnEnable") |> stopnpctimer()

        get_server_temp_var(ctx, "JupeElevatorInUse2", 0) == 4 and
          get_npc_var_of(ctx, "MyMobs", "Guard-2#ufe", 0) < 1 and
          get_npc_var_of(ctx, "MyMobs", "Guard-3#ufe", 0) < 1 and
            get_npc_var_of(ctx, "MyMobs", "Guard-4#ufe", 0) < 1 ->
          ctx |> donpcevent("GuardEnd#ufe::OnEnable") |> stopnpctimer()

        true ->
          ctx
      end
    else
      ctx
    end
  end
end
