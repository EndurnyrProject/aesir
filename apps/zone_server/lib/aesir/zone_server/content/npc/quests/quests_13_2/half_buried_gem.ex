defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.HalfBuriedGem do
  @moduledoc """
  Manages a half-buried quest gem and its monster encounter.

  ## Behavior

  - Delegates gem interaction to the shared jewel function.
  - Hides the gem during its monster encounter and restores it after the monsters die or the timer expires.

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
        map: "spl_fild02",
        x: 27,
        y: 218,
        dir: 0,
        sprite: 844,
        name: "Half-buried Gem",
        scope: :shared,
        unique_name: "Half-buried Gem#1"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.Jewel132

  @gem "Half-buried Gem#1"
  @mob_event "Half-buried Gem#1::OnMyMobDead"

  @impl true
  def on_event("OnInit", ctx), do: hideoffnpc(ctx, @gem)

  def on_event("OnEnable", ctx), do: ctx |> hideoffnpc(@gem) |> stopnpctimer()

  def on_event("OnDisable", ctx) do
    ctx
    |> initnpctimer()
    |> summon_mob(mob_id: 1051, map: "spl_fild02", at: {25, 220}, amount: 10, event: @mob_event)
    |> hideonnpc(@gem)
  end

  def on_event("OnMyMobDead", ctx) do
    if mobcount(ctx, "spl_fild02", @mob_event) < 1 do
      ctx |> donpcevent("Half-buried Gem#1::OnEnable") |> stopnpctimer()
    else
      ctx
    end
  end

  def on_event("OnTimer300000", ctx) do
    ctx
    |> killmonster("spl_fild02", @mob_event)
    |> donpcevent("Half-buried Gem#1::OnEnable")
    |> stopnpctimer()
  end

  @impl true
  def on_talk(ctx), do: Jewel132.call(ctx, ["Red", 1])
end
