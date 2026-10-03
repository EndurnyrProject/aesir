defmodule Aesir.ZoneServer.Integration.HighPriestMobCastTest do
  @moduledoc """
  Exercises the mob skill executor's real Assumptio path: monster rows cast it
  on themselves and on a friendly monster, boss allies included, in both modes.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @map "prontera"

  test "a self row blesses the casting mob with Assumptio" do
    mob = spawn_mob({150, 150})
    row = %{skill: "HP_ASSUMPTIO", skill_id: 361, target: :self, level: 5}

    assert :ok = Executor.execute(get_mob_state(mob.pid), row)

    assert %{val1: 5} = StatusStorage.get_status(:mob, mob.unit_id, :sc_assumptio)
  end

  test "a friend row blesses a wounded boss ally" do
    caster = spawn_mob({150, 150})
    boss = spawn_mob({151, 150}, modes: [:boss], hp: 10, max_hp: 1_000)
    row = %{skill: "HP_ASSUMPTIO", skill_id: 361, target: :friend, level: 5}

    assert :ok = Executor.execute(get_mob_state(caster.pid), row)

    assert StatusStorage.has_status?(:mob, boss.unit_id, :sc_assumptio)
  end

  defp spawn_mob(position, opts \\ []) do
    mob = start_mob_session([map_name: @map, position: position] ++ opts)
    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end
end
