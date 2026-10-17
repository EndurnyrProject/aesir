defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrapTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(Knockback)
    Mimic.copy(StatusInterpreter)
    :ok
  end

  @cell {50, 50}
  @now 10_000

  defp group(attrs \\ []) do
    struct!(
      %Group{
        group_id: 1,
        skill_id: 115,
        skill_name: :ht_skidtrap,
        level: 3,
        caster_id: 1000,
        caster_type: :player,
        map_name: "prontera",
        center: {50, 50},
        origin: {40, 50},
        cells: [{50, 50}],
        next_tick_at: 0,
        expires_at: 180_000,
        interval: 1_000,
        state: %{trap: armed_trap()}
      },
      attrs
    )
  end

  @tag game_mode: :renewal
  test "places a hidden single-cell trap with typed lifecycle state" do
    stub(UnitRegistry, :get_unit_info, fn :player, 1000 ->
      {:ok, %{stats: %{dex: 1, int: 1, base_level: 1}}}
    end)

    assert {:ok, placement} = HtSkidtrap.on_place(group(state: %{}))
    assert placement.cells == [{50, 50}]
    assert placement.visibility == :party_only
    assert placement.duration == 180_000
    assert placement.state.trap.phase == :armed
  end

  describe "renewal" do
    @describetag game_mode: :renewal

    test "a player trap pushes eligible monsters from its placement origin at every level, then stops them" do
      stub_units([player(1000)])
      test_pid = self()

      for level <- 1..5 do
        expect(Knockback, :knockback, fn :mob, 2000, 40, 50, distance ->
          send(test_pid, {:pushed, distance})
          :ok
        end)

        expect(StatusInterpreter, :apply_status, fn :mob, 2000, :sc_stop, options ->
          assert options[:duration] == 3_000
          assert options[:bypass_resistance] == true
          assert options[:caster_id] == 1000
          assert options[:source_type] == :player
          send(test_pid, :stopped)
          :ok
        end)

        assert {:ok, %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}}} =
                 HtSkidtrap.on_unit_hit(group(level: level), @cell, {:mob, 2000}, @now)

        expected = level + 5
        assert {:messages, [{:pushed, ^expected}, :stopped]} = Process.info(self(), :messages)
        assert_received {:pushed, _}
        assert_received :stopped
      end
    end

    test "a target rejecting Stop is still pushed and the trap is spent" do
      stub_units([player(1000)])
      expect(Knockback, :knockback, fn :mob, 2000, 40, 50, 8 -> :ok end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2000, :sc_stop, _ -> {:error, :immune} end)

      assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
               HtSkidtrap.on_unit_hit(group(), @cell, {:mob, 2000}, @now)
    end

    test "bosses do not set the trap off" do
      stub_units([
        player(1000),
        mob(2000, modes: [:detector, :status_immune, :knockback_immune]),
        mob(2001)
      ])

      assert [{:mob, 2001}] =
               HtSkidtrap.unit_targets(group(), @cell, [{:mob, 2000}, {:mob, 2001}])
    end

    test "status-immune targets do not set the trap off" do
      stub_units([player(1000), mob(2000, modes: [:status_immune]), mob(2001)])

      assert [{:mob, 2001}] =
               HtSkidtrap.unit_targets(group(), @cell, [{:mob, 2000}, {:mob, 2001}])
    end
  end

  describe "pre-renewal" do
    @describetag game_mode: :pre_renewal

    test "a boss sets the trap off" do
      stub_units([player(1000), mob(2000, modes: [:detector, :status_immune, :knockback_immune])])

      assert [{:mob, 2000}] = HtSkidtrap.unit_targets(group(), @cell, [{:mob, 2000}])
    end

    test "pushes a monster without Stop and makes it forget its target" do
      stub_units([player(1000), mob(2000)])
      test_pid = self()
      expect(Knockback, :knockback, fn :mob, 2000, 40, 50, 8 -> :ok end)
      reject(&StatusInterpreter.apply_status/4)
      expect(MobSession, :set_target, fn ^test_pid, nil -> :ok end)

      assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
               HtSkidtrap.on_unit_hit(group(), @cell, {:mob, 2000}, @now)
    end
  end

  test "a target standing on the placement cell is pushed from that cell" do
    stub_units([mob(1000)])
    stub(StatusInterpreter, :apply_status, fn :player, 3000, :sc_stop, _ -> :ok end)
    expect(Knockback, :knockback, fn :player, 3000, 50, 50, 8 -> :ok end)

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtSkidtrap.on_unit_hit(
               group(caster_type: :mob, origin: {50, 50}),
               @cell,
               {:player, 3000},
               @now
             )
  end

  test "a mob trap affects players and same-side contacts do not set it off" do
    stub_units([mob(1000), player(3000), mob(2000)])
    stub(StatusInterpreter, :apply_status, fn :player, 3000, :sc_stop, _ -> :ok end)
    expect(Knockback, :knockback, fn :player, 3000, 40, 50, 8 -> :ok end)

    mob_trap = group(caster_type: :mob)

    assert [{:player, 3000}] =
             HtSkidtrap.unit_targets(mob_trap, @cell, [{:player, 3000}, {:mob, 2000}])

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtSkidtrap.on_unit_hit(mob_trap, @cell, {:player, 3000}, @now)
  end
end
