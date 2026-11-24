defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Humspawner do
  @moduledoc """
  Spawns guards when the research documents are taken.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "lhz_in01", x: 235, y: 129, dir: 0, sprite: 139, name: "HuMSpawner", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnMonster", ctx), do: spawn_guards(ctx)
  def on_event("OnTimer60000", ctx), do: clear_guards(ctx)
  def on_event("OnMonsterDead", ctx), do: monster_dead(ctx)
  @impl true
  def on_talk(ctx) do
    spawn_guards(ctx)
  end

  defp spawn_guards(ctx) do
    ctx =
      if Rathena.truthy?(Enum.random(0..1)) do
        mapannounce(
          ctx,
          "lhz_in01",
          "Intruder alert! Protect the research documents!",
          1,
          16_711_680
        )
      else
        mapannounce(ctx, "lhz_in01", "Intruder alert! Intruder alert!", 1, 16_711_680)
      end

    ctx
    |> summon_mob(
      mob_id: 1682,
      map: "lhz_in01",
      at: {208, 133},
      name: "Guard",
      event: "HuMSpawner::OnMonsterDead"
    )
    |> summon_mob(
      mob_id: 1682,
      map: "lhz_in01",
      at: {217, 135},
      name: "Guard",
      event: "HuMSpawner::OnMonsterDead"
    )
    |> initnpctimer()
  end

  defp clear_guards(ctx) do
    ctx |> killmonster("lhz_in01", "HuMSpawner::OnMonsterDead") |> stopnpctimer()
  end

  defp monster_dead(ctx) do
    ctx
  end
end
