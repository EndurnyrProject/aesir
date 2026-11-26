defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Callmonster12 do
  @moduledoc """
  Controls the witch’s Dark Lord encounter.

  ## Behavior

  - Summons the encounter monsters, enables Serin when they are defeated, and resets them.

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
        map: "que_sign01",
        x: 1,
        y: 2,
        dir: 0,
        sprite: -1,
        name: "CallMonster",
        scope: :shared,
        unique_name: "CallMonster#witch"
      }
    ]

  @impl true
  def on_event("Oncall", ctx), do: ev_oncall(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  def on_event("OnReset", ctx), do: ev_onreset(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oncall(ctx)
  end

  def ev_oncall(ctx) do
    ctx
    |> summon_mob(
      mob_id: 1605,
      map: "que_sign01",
      at: {196, 195},
      name: "Dark Lord Incarnation",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1522,
      map: "que_sign01",
      at: {180, 180},
      name: "Ancient Mummy",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1522,
      map: "que_sign01",
      at: {210, 210},
      name: "Ancient Mummy",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1475,
      map: "que_sign01",
      at: {200, 200},
      name: "Ancient Wraith",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1475,
      map: "que_sign01",
      at: {200, 180},
      name: "Ancient Wraith",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1423,
      map: "que_sign01",
      at: {180, 200},
      name: "Rotten Corpse",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1423,
      map: "que_sign01",
      at: {205, 205},
      name: "Rotten Corpse",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1423,
      map: "que_sign01",
      at: {190, 190},
      name: "Rotten Corpse",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1423,
      map: "que_sign01",
      at: {205, 190},
      name: "Rotten Corpse",
      event: "CallMonster#witch::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1423,
      map: "que_sign01",
      at: {190, 205},
      name: "Rotten Corpse",
      event: "CallMonster#witch::OnMyMobDead"
    )
  end

  def ev_onmymobdead(ctx) do
    if mobcount(ctx, "que_sign01", "CallMonster#witch::OnMyMobDead") < 1 do
      donpcevent(ctx, "Serin#witch::OnEnable")
    else
      ctx
    end
  end

  def ev_onreset(ctx) do
    killmonster(ctx, "que_sign01", "CallMonster#witch::OnMyMobDead")
  end
end
