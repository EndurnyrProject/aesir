defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.EggKeeperDraco0 do
  @moduledoc """
  Reenables an egg keeper after its death timer.

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
        x: 206,
        y: 157,
        dir: 3,
        sprite: -1,
        name: "Egg Keeper Draco",
        scope: :shared,
        unique_name: "Egg Keeper Draco#13_4"
      }
    ]

  @impl true
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  def on_event("OnTimer180000", ctx), do: ev_ontimer180000(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_onmymobdead(ctx) do
    initnpctimer(ctx)
  end

  def ev_ontimer180000(ctx) do
    ctx |> enablenpc("Egg Keeper Draco#13_2") |> stopnpctimer()
  end
end
