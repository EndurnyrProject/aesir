defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.TickTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Tick
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 49_001
  @ally_id 49_002
  @stranger_id 49_003
  @mob_id 49_004
  @homunculus_id 49_005
  @party 77
  @map "prontera"

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Effects)
    test_pid = self()

    stub(Combat, :resolve_combatant, fn :player, @caster_id ->
      {:ok, %{unit_type: :player, unit_id: @caster_id, map_name: @map, party_id: @party}}
    end)

    stub(Effects, :bless, fn _group, target ->
      send(test_pid, {:bless, target})
      :ok
    end)

    stub(Effects, :afflict, fn _group, _caster_state, target ->
      send(test_pid, {:afflict, target})
      :ok
    end)

    :ok
  end

  test "blesses a party member, afflicts an enemy, and leaves a stranger alone" do
    register_player(@caster_id, @party)
    register_player(@ally_id, @party)
    register_player(@stranger_id, 0)
    register_mob(@mob_id)
    group = group(5, fn 100 -> 1 end)

    assert :ok = Tick.strike(group, {:player, @ally_id})
    assert :ok = Tick.strike(group, {:mob, @mob_id})
    assert :ok = Tick.strike(group, {:player, @stranger_id})

    assert_received {:bless, {:player, @ally_id}}
    assert_received {:afflict, {:mob, @mob_id}}
    refute_received {:bless, {:player, @stranger_id}}
    refute_received {:afflict, {:player, @stranger_id}}
  end

  test "the per-unit roll passes at 50 + 5 * level and fails above it" do
    register_player(@caster_id, @party)
    register_player(@ally_id, @party)

    assert :ok = Tick.strike(group(4, fn 100 -> 70 end), {:player, @ally_id})
    assert_received {:bless, {:player, @ally_id}}

    assert :ok = Tick.strike(group(4, fn 100 -> 71 end), {:player, @ally_id})
    refute_received {:bless, _}
  end

  test "the caster's own homunculus is blessed without a party" do
    register_player(@caster_id, 0)

    :ok =
      UnitRegistry.register_unit(
        :homunculus,
        @homunculus_id,
        HomunculusState,
        TrapTestHelper.homunculus(@homunculus_id, @caster_id),
        self()
      )

    assert :ok = Tick.strike(group(1, fn 100 -> 1 end), {:homunculus, @homunculus_id})

    assert_received {:bless, {:homunculus, @homunculus_id}}
  end

  test "on a PvP no-party map a party member is neither blessed nor afflicted" do
    :ok = MapFlags.set_runtime(@map, :pvp, true)
    :ok = MapFlags.set_runtime(@map, :pvp_noparty, true)
    register_player(@caster_id, @party)
    register_player(@ally_id, @party)

    stub(Targeting, :validate_enemy, fn _caster, _target ->
      {:error, :not_enemy}
    end)

    assert :ok = Tick.strike(group(1, fn 100 -> 1 end), {:player, @ally_id})

    refute_received {:bless, _}
    refute_received {:afflict, _}
  end

  defp group(level, rng) do
    %Group{
      group_id: 11,
      skill_id: 369,
      skill_name: :pa_gospel,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      party_id: @party,
      map_name: @map,
      center: {50, 50},
      cells: [{50, 50}],
      state: %{rng: rng}
    }
  end

  defp register_player(id, party_id) do
    :ok = UnitRegistry.register_player(TrapTestHelper.player(id, %{party_id: party_id}), self())
  end

  defp register_mob(id) do
    :ok = UnitRegistry.register_unit(:mob, id, MobState, TrapTestHelper.mob(id), self())
  end
end
