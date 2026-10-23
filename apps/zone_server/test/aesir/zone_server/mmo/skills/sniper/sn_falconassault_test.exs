defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnFalconassaultTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.SnFalconassault
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :setup_ets_tables

  test "requires the falcon option bit" do
    caster = %PlayerState{character_id: 1001, option: 0}
    definition = SnFalconassault.definition()

    assert {:error, :falcon_not_equipped} =
             SnFalconassault.begin_attempt(caster, {:unit, 2001}, 5, definition)

    falconer = %{caster | option: Option.id(:falcon)}

    assert {:ok, ^falconer} =
             SnFalconassault.begin_attempt(falconer, {:unit, 2001}, 5, definition)
  end

  test "a monster casts it: no falcon to check and no Steel Crow bonus" do
    definition = SnFalconassault.definition()
    mob = mob()

    assert :ok = Castability.check(definition, :mob)
    assert {:ok, ^mob} = SnFalconassault.begin_attempt(mob, {:unit, 2001}, 5, definition)

    stats = MobState.get_stats(mob)
    test_pid = self()

    expect(Combat, :execute_misc_attack, fn ^mob, {:mob, 2001}, opts ->
      send(test_pid, {:cast, opts})
      :ok
    end)

    assert :ok = SnFalconassault.mob_cast(mob, {:unit, :mob, 2001}, 5, definition, %{})

    assert_received {:cast, opts}

    assert opts[:base_damage] ==
             Formulas.falcon_assault_damage(5, 0, %{
               agi: stats.agi,
               dex: stats.dex,
               int: stats.int
             })

    assert opts[:element] == :neutral
  end

  defp mob do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5_000, spawn_area: nil}
    MobState.new(9_001, data, spawn, "prontera", 10, 10)
  end
end
