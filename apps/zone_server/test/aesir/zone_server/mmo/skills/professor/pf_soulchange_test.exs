defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulchangeTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulchange
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  @caster_id 8_001
  @ally_id 8_002
  @mob_id 8_003

  defp player(id, sp, opts) do
    %PlayerState{
      character_id: id,
      map_name: "prontera",
      x: 100,
      y: 100,
      action_state: :idle,
      party_id: Keyword.get(opts, :party_id, 0),
      guild_id: Keyword.get(opts, :guild_id, 0),
      stats: %{
        current_state: %{hp: 100, sp: sp},
        derived_stats: %{max_hp: 100, max_sp: Keyword.get(opts, :max_sp, 200)}
      }
    }
  end

  defp caster(sp \\ 100, opts \\ []),
    do: player(@caster_id, sp, Keyword.put_new(opts, :party_id, 5))

  defp register_ally(sp, opts \\ [party_id: 5]) do
    ally = player(@ally_id, sp, opts)
    :ok = UnitRegistry.register_unit(:player, @ally_id, PlayerState, ally, self())
    ally
  end

  defp register_mob do
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }

    mob = MobState.new(@mob_id, definition, spawn, "prontera", 101, 100)
    :ok = UnitRegistry.register_unit(:mob, @mob_id, MobState, mob, self())
  end

  defp expect_set_sp do
    test_pid = self()

    expect(PlayerSession, :set_vitals, fn pid, [sp: sp] ->
      send(test_pid, {:set_sp, pid, sp})
      :ok
    end)
  end

  defp cast(caster, target_id),
    do: PfSoulchange.cast(caster, {:unit, target_id}, 1, PfSoulchange.definition())

  defp sp(%PlayerState{stats: stats}), do: stats.current_state.sp

  @tag game_mode: :renewal
  test "renewal pays the cost, then halves both SP pools before swapping them" do
    register_ally(40)
    expect_set_sp()

    assert {:ok, caster} = cast(caster(100), @ally_id)

    assert_received {:set_sp, _pid, 47}
    assert sp(caster) == 20
  end

  @tag game_mode: :renewal
  test "renewal hands an Asura-ready target its whole own SP back" do
    register_ally(40)
    :ok = StatusStorage.apply_status(:player, @ally_id, :sc_extremityfist)
    expect_set_sp()

    assert {:ok, caster} = cast(caster(100), @ally_id)

    assert_received {:set_sp, _pid, 40}
    assert sp(caster) == 20
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal pays the cost, then swaps the two SP pools whole" do
    register_ally(40)
    expect_set_sp()

    assert {:ok, caster} = cast(caster(100), @ally_id)

    assert_received {:set_sp, _pid, 95}
    assert sp(caster) == 40
  end

  test "a monster yields 3% of the caster's max SP once, after the cost" do
    register_mob()

    assert {:ok, gained} = cast(caster(100), @mob_id)
    assert sp(gained) == 101

    assert {:error, :already_exchanged} = cast(gained, @mob_id)
  end

  test "the cost is required up front but paid by the cast itself" do
    cost = PfSoulchange.dynamic_cost(caster(100), {:unit, @ally_id}, 1, PfSoulchange.definition())
    assert {cost.sp, cost.sp_requirement} == {0, 5}
  end

  test "a swap never leaves the caster below zero after the cost" do
    register_ally(0)
    expect_set_sp()

    {:ok, caster} = cast(caster(5), @ally_id)
    assert sp(caster) == 0
  end

  test "only a party or guild member other than the caster is a valid player target" do
    definition = PfSoulchange.definition()

    register_ally(40, guild_id: 9)

    assert PfSoulchange.validate(caster(100, guild_id: 9), {:unit, @ally_id}, 1, definition) ==
             :ok

    assert PfSoulchange.validate(caster(100), {:unit, @ally_id}, 1, definition) ==
             {:error, :invalid_target}

    :ok = UnitRegistry.register_unit(:player, @caster_id, PlayerState, caster(), self())

    assert PfSoulchange.validate(caster(), {:unit, @caster_id}, 1, definition) ==
             {:error, :invalid_target}
  end
end
