defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Callmonster do
  @moduledoc """
  Controls Serin’s Dark Lord encounter.

  ## Behavior

  - Summons the boss, enables Serin when it dies, and resets the encounter.

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
        x: 50,
        y: 1,
        dir: 0,
        sprite: -1,
        name: "CallMonster",
        scope: :shared,
        unique_name: "CallMonster#serin"
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
    summon_mob(ctx,
      mob_id: 1605,
      map: "que_sign01",
      at: {196, 44},
      name: "Dark Lord Incarnation",
      event: "CallMonster#serin::OnMyMobDead"
    )
  end

  def ev_onmymobdead(ctx) do
    if mobcount(ctx, "que_sign01", "CallMonster#serin::OnMyMobDead") < 1 do
      donpcevent(ctx, "Serin#serin::OnEnable")
    else
      ctx
    end
  end

  def ev_onreset(ctx) do
    killmonster(ctx, "que_sign01", "CallMonster#serin::OnMyMobDead")
  end
end
