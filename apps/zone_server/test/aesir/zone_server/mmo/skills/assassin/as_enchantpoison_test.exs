defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsEnchantpoisonTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsEnchantpoison
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "defines Enchant Poison's complete static level formulas" do
    definition = AsEnchantpoison.definition()

    assert definition.id == 138
    assert definition.name == :as_enchantpoison
    assert definition.status == :sc_encpoison
    assert definition.max_level == 10
    assert definition.target_type == :target_ally
    assert definition.range == 1
    assert definition.sp_cost == List.duplicate(20, 10)
    assert definition.duration == Enum.map(1..10, &(30_000 + 15_000 * (&1 - 1)))
  end

  test "self and a live same-party same-map ally are valid and receive the level duration" do
    caster = player_state(1, party_id: 7)
    ally = player_state(2, party_id: 7)
    register_player(caster)
    register_player(ally, 51, 50)

    assert {:ok, self_cast} = Interpreter.cast(caster, 138, 1, :self)
    assert self_cast.stats.current_state.sp == 80
    assert_status(1, 1, 30_000)

    assert {:ok, ally_cast} = Interpreter.cast(caster, 138, 10, {:unit, 2})
    assert ally_cast.stats.current_state.sp == 80
    assert_status(2, 10, 165_000)
  end

  test "dead, non-party, cross-map, out-of-range, missing, and non-player targets fail uncommitted" do
    caster = player_state(1, party_id: 7)
    register_player(caster)

    targets = [
      {2, player_state(2, party_id: 7) |> put_in([Access.key!(:action_state)], :dead), 51, 50},
      {3, player_state(3, party_id: 0), 51, 50},
      {4, player_state(4, party_id: 8), 51, 50},
      {5, player_state(5, party_id: 7, map_name: "geffen"), 51, 50},
      {6, player_state(6, party_id: 7), 52, 50}
    ]

    for {id, target, x, y} <- targets do
      register_player(target, x, y)
      assert {:error, _reason} = Interpreter.cast(caster, 138, 1, {:unit, id})
      assert caster.stats.current_state.sp == 100
      refute StatusStorage.has_status?(:player, id, :sc_encpoison)
    end

    assert {:error, _reason} = Interpreter.cast(caster, 138, 1, {:unit, 99})
    refute StatusStorage.has_status?(:player, 99, :sc_encpoison)

    offline = player_state(7, party_id: 7)
    offline_pid = spawn(fn -> :ok end)
    monitor = Process.monitor(offline_pid)
    # Reason is deliberately unbound: the spawned process can already be gone by
    # the time the monitor is set up, in which case the DOWN reason is :noproc,
    # not :normal. Either way the pid is dead, which is all this needs.
    assert_receive {:DOWN, ^monitor, :process, ^offline_pid, _reason}
    :ok = UnitRegistry.register_player(offline, offline_pid)
    :ok = SpatialIndex.add_unit(:player, 7, 51, 50, "prontera")
    assert {:error, _reason} = Interpreter.cast(caster, 138, 1, {:unit, 7})
    refute StatusStorage.has_status?(:player, 7, :sc_encpoison)

    mob = %MobState{
      instance_id: 100,
      mob_id: 1002,
      mob_data: %{modes: []},
      spawn_ref: %{},
      x: 51,
      y: 50,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, 100, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, 100, 51, 50, "prontera")
    assert {:error, _reason} = Interpreter.cast(caster, 138, 1, {:unit, 100})
    refute StatusStorage.has_status?(:mob, 100, :sc_encpoison)
  end

  defp assert_status(id, level, expected_duration) do
    assert %{} = status = StatusStorage.get_status(:player, id, :sc_encpoison)
    assert status.val1 == level

    assert_in_delta status.expires_at - System.monotonic_time(:millisecond),
                    expected_duration,
                    100
  end

  defp register_player(player, x \\ 50, y \\ 50) do
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_unit(:player, player.character_id, x, y, player.map_name)
  end

  defp player_state(id, opts) do
    base =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: Keyword.get(opts, :map_name, "prontera"),
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 12
      })

    stats =
      base.stats
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], 100)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 100)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{138 => 10})

    %{base | stats: stats, party_id: Keyword.get(opts, :party_id, 0)}
  end
end
