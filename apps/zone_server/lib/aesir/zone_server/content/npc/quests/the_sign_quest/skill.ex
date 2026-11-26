defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Skill do
  @moduledoc """
  Spawns and removes monsters for the maze encounter.

  ## Behavior

  - Spawns Flora and Marine Spheres when enabled and removes them when disabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_maze02",
        x: 132,
        y: 132,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#skill"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)

  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    ctx
    |> summon_mob(
      mob_id: 1118,
      map: "prt_maze02",
      at: {14, 177},
      name: "Flora",
      event: "#skill::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1118,
      map: "prt_maze02",
      at: {17, 171},
      name: "Flora",
      event: "#skill::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1118,
      map: "prt_maze02",
      at: {24, 173},
      name: "Flora",
      event: "#skill::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1142,
      map: "prt_maze02",
      at: {17, 175},
      name: "Marine Sphere",
      event: "#skill::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1142,
      map: "prt_maze02",
      at: {17, 168},
      name: "Marine Sphere",
      event: "#skill::OnMyMobDead"
    )
  end

  def ev_ondisable(ctx) do
    killmonster(ctx, "prt_maze02", "#skill::OnMyMobDead")
  end

  def ev_onmymobdead(ctx), do: ctx
end
