defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.EggKeeperDraco do
  @moduledoc """
  Summons an egg keeper when a player approaches.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nyd_dun02",
        x: 201,
        y: 157,
        dir: 5,
        sprite: 2013,
        name: "Egg Keeper Draco",
        scope: :shared,
        unique_name: "Egg Keeper Draco#13_1",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    enablenpc(ctx, "Egg Keeper Draco#13_1")
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "Egg Keeper Draco#13_1")
  end

  def ev_ontouch(ctx) do
    ctx
    |> disablenpc("Egg Keeper Draco#13_1")
    |> summon_mob(
      mob_id: 2013,
      map: "nyd_dun02",
      at: {201, 157},
      event: "Egg Keeper Draco#13_3::OnMyMobDead"
    )
  end
end
