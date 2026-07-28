defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaFrostjokerTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaFrostjoker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 1_000

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition and cast capture the pinned delayed event" do
    assert {:ok, BaFrostjoker} = Catalog.active_module_for(:ba_frostjoker)
    assert {:ok, definition} = Catalog.by_id(318)

    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.range == 0
    assert definition.sp_cost == [12, 14, 16, 18, 20]
    assert definition.cast_time == List.duplicate(0, 5)
    assert definition.fixed_cast_time == List.duplicate(0, 5)
    assert definition.after_cast_delay == List.duplicate(300, 5)
    assert definition.cooldown == List.duplicate(5_000, 5)

    caster = player_state()
    test_pid = self()

    scheduler = fn module, payload, delay ->
      send(test_pid, {:scheduled, module, payload, delay})
      make_ref()
    end

    assert {:ok, ^caster} =
             BaFrostjoker.cast(caster, :self, 3, definition, scheduler)

    assert_received {:scheduled, BaFrostjoker,
                     %{
                       map_name: "task20_map",
                       x: 100,
                       y: 200,
                       caster_type: :player,
                       caster_id: @caster_id,
                       deferred_epoch: 7,
                       skill_level: 3
                     }, 3_000}
  end

  test "mob casts capture their identity through the same deferred callback" do
    caster = mob_state()
    test_pid = self()

    scheduler = fn module, payload, delay ->
      send(test_pid, {:scheduled, module, payload, delay})
      make_ref()
    end

    assert {:ok, ^caster} =
             BaFrostjoker.cast(
               caster,
               {:unit, caster.instance_id},
               5,
               BaFrostjoker.definition(),
               scheduler
             )

    assert_received {:scheduled, BaFrostjoker,
                     %{
                       caster_type: :mob,
                       caster_id: @caster_id,
                       deferred_epoch: 7,
                       skill_level: 5
                     }, 3_000}
  end

  test "mob deferred resolution uses the same callback and source identity" do
    caster = mob_state()
    register(:mob, caster)
    register(:player, player(2, x: 101, y: 200))

    expect(StatusInterpreter, :apply_status, fn :player, 2, :sc_freeze, params ->
      assert params[:success_rate] == 40
      assert params[:duration] == 27_000
      assert params[:caster_id] == @caster_id
      assert params[:source_type] == :mob
      :ok
    end)

    assert :ok =
             BaFrostjoker.deferred(
               %{
                 map_name: caster.map_name,
                 x: caster.x,
                 y: caster.y,
                 caster_type: :mob,
                 caster_id: caster.instance_id,
                 deferred_epoch: caster.deferred_epoch,
                 skill_level: 5
               },
               caster
             )
  end

  test "area size defaults to 14 independently of view range" do
    previous_view_range = Application.get_env(:zone_server, :view_range)
    previous_area_size = Application.get_env(:zone_server, :frost_joker_area_size)

    on_exit(fn ->
      restore_env(:view_range, previous_view_range)
      restore_env(:frost_joker_area_size, previous_area_size)
    end)

    Application.put_env(:zone_server, :view_range, 3)
    Application.delete_env(:zone_server, :frost_joker_area_size)

    assert Config.view_range() == 3
    assert Config.frost_joker_area_size() == 14
  end

  test "enemy and current-party chances and durations are exact at every level" do
    caster = player(1, x: 100, y: 200, party_id: 10)
    register(:player, caster)
    register(:mob, mob(2, 101, 200))
    register(:player, player(3, x: 99, y: 200, party_id: 10))

    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn unit_type, unit_id, :sc_freeze, params ->
      send(test_pid, {:freeze, unit_type, unit_id, params})
      :ok
    end)

    for {enemy_chance, party_chance, level} <-
          Enum.zip([[20, 25, 30, 35, 40], [5.0, 6.2, 7.5, 8.7, 10.0], 1..5]) do
      assert :ok = BaFrostjoker.deferred(payload(caster, level), caster)

      assert_receive {:freeze, :mob, 2, enemy_params}
      assert enemy_params[:success_rate] == enemy_chance
      assert enemy_params[:duration] == 27_000

      assert_receive {:freeze, :player, 3, party_params}
      assert party_params[:success_rate] == party_chance
      assert party_params[:duration] == 15_000
    end
  end

  test "resolution uses the captured inclusive square and current eligibility" do
    caster = player(1, x: 100, y: 200, party_id: 10)
    register(:player, caster)

    register(:mob, mob(2, 114, 214))
    register(:mob, mob(3, 115, 200))
    register(:player, player(4, x: 86, y: 186, party_id: 10))
    register(:player, player(5, x: 101, y: 200))
    register(:player, player(6, x: 102, y: 200, party_id: 10, option: Option.id(:invisible)))
    register(:player, player(7, x: 103, y: 200, party_id: 10, option: Option.id(:madogear)))

    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn unit_type, unit_id, :sc_freeze, params ->
      send(test_pid, {:freeze, unit_type, unit_id, params})
      :ok
    end)

    payload = payload(caster, 1)
    assert :ok = BaFrostjoker.deferred(payload, caster)

    assert_received {:freeze, :mob, 2, enemy_params}
    assert enemy_params[:success_rate] == 20
    assert enemy_params[:duration] == 27_000
    assert enemy_params[:caster_id] == 1
    assert enemy_params[:source_type] == :player
    refute Keyword.has_key?(enemy_params, :bypass_resistance)
    refute Keyword.has_key?(enemy_params, :resistance_roll)

    assert_received {:freeze, :player, 4, party_params}
    assert party_params[:success_rate] == 5
    assert party_params[:duration] == 15_000
    assert party_params[:caster_id] == 1
    assert party_params[:source_type] == :player

    refute_received {:freeze, _, 1, _}
    refute_received {:freeze, _, 3, _}
    refute_received {:freeze, _, 5, _}
    refute_received {:freeze, _, 6, _}
    refute_received {:freeze, _, 7, _}
  end

  test "walking preserves the event and its captured origin" do
    original = player(1, x: 100, y: 200)
    walked = PlayerState.update_position(original, 130, 230)
    register(:player, walked)
    register(:mob, mob(2, 100, 200))

    test_pid = self()

    expect(StatusInterpreter, :apply_status, fn :mob, 2, :sc_freeze, _params ->
      send(test_pid, :frozen_at_original_origin)
      :ok
    end)

    assert :ok = BaFrostjoker.deferred(payload(original, 5), walked)
    assert_received :frozen_at_original_origin
  end

  test "death with revival and same-map or cross-map relocation invalidate the exact epoch" do
    original = player(1, x: 100, y: 200)
    register(:mob, mob(2, 100, 200))
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, died} = PlayerState.transition_to(original, :dead)

    revived =
      died
      |> Map.put(:action_state, :idle)
      |> put_in([Access.key!(:stats), Access.key!(:current_state), Access.key!(:hp)], 1)

    same_map_teleport = PlayerState.relocate(original, original.map_name, 120, 220)
    cross_map_teleport = PlayerState.relocate(original, "other_map", 100, 200)

    for stale <- [revived, same_map_teleport, cross_map_teleport] do
      :ok = SpatialIndex.add_unit(:player, stale.character_id, stale.x, stale.y, stale.map_name)
      assert :ok = BaFrostjoker.deferred(payload(original, 5), stale)
      :ok = SpatialIndex.remove_unit(:player, stale.character_id)
    end
  end

  test "a caster removed from the spatial index cancels resolution" do
    caster = player(1, x: 100, y: 200)
    register(:mob, mob(2, 100, 200))
    reject(&StatusInterpreter.apply_status/4)

    assert :ok = BaFrostjoker.deferred(payload(caster, 5), caster)
  end

  test "disconnect destroys the process that owns the delayed event" do
    parent = self()
    caster = player_state()

    {pid, monitor} =
      spawn_monitor(fn ->
        scheduler = fn module, deferred_payload, 3_000 ->
          Process.send_after(self(), {:skill, {:deferred, module, deferred_payload}}, 20)
        end

        assert {:ok, ^caster} =
                 BaFrostjoker.cast(caster, :self, 1, BaFrostjoker.definition(), scheduler)

        send(parent, :scheduled_before_disconnect)
      end)

    assert_receive :scheduled_before_disconnect
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}
    refute_receive {:skill, {:deferred, BaFrostjoker, _payload}}, 50
  end

  defp player_state do
    %PlayerState{
      character_id: @caster_id,
      x: 100,
      y: 200,
      map_name: "task20_map",
      deferred_epoch: 7,
      stats: nil
    }
  end

  defp mob_state do
    %MobState{
      instance_id: @caster_id,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 100,
      y: 200,
      map_name: "task20_map",
      deferred_epoch: 7,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }
  end

  defp player(id, opts) do
    state =
      %Character{
        id: id,
        account_id: id,
        name: "Player#{id}",
        last_map: "task20_map",
        last_x: Keyword.fetch!(opts, :x),
        last_y: Keyword.fetch!(opts, :y),
        class: 19,
        base_level: 100,
        job_level: 50,
        sex: "M",
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        party_id: Keyword.get(opts, :party_id, 0)
      }
      |> PlayerState.new()

    %{state | option: Keyword.get(opts, :option, 0)}
  end

  defp mob(id, x, y) do
    %{mob_state() | instance_id: id, x: x, y: y, deferred_epoch: 0}
  end

  defp register(:player, %PlayerState{} = state) do
    :ok = UnitRegistry.register_unit(:player, state.character_id, PlayerState, state, self())
    :ok = SpatialIndex.add_unit(:player, state.character_id, state.x, state.y, state.map_name)
  end

  defp register(:mob, %MobState{} = state) do
    :ok = UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, state.instance_id, state.x, state.y, state.map_name)
  end

  defp payload(caster, level) do
    %{
      map_name: caster.map_name,
      x: caster.x,
      y: caster.y,
      caster_type: :player,
      caster_id: caster.character_id,
      deferred_epoch: caster.deferred_epoch,
      skill_level: level
    }
  end

  defp restore_env(key, nil), do: Application.delete_env(:zone_server, key)
  defp restore_env(key, value), do: Application.put_env(:zone_server, key, value)
end
