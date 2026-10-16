defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzQuagmireTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzQuagmire
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(UnitRegistry)
    :ok
  end

  describe "on_place/1" do
    test "creates the canonical 3x3 field and reconciliation cadence" do
      assert {:ok, placement} = WzQuagmire.on_place(group(level: 5))

      assert Enum.sort(placement.cells) ==
               Enum.sort(for(x <- 9..11, y <- 19..21, do: {x, y}))

      assert placement.interval == 1_000
      assert placement.initial_delay == 0
      assert placement.duration == 25_000
    end
  end

  describe "field_support/1" do
    test "uses canonical player and mob penalties at every level" do
      for level <- 1..5 do
        %{params: params_for} = WzQuagmire.field_support(group(level: level))
        assert params_for.(:player, 200) == [level: level, val1: level, val2: 5 * level]
        assert params_for.(:mob, 200) == [level: level, val1: level, val2: 10 * level]
      end
    end

    test "filters caster, allies, and dead units without calling a session" do
      stub_unit_registry(%{
        {:player, 100} => player(100, party_id: 1),
        {:player, 101} => player(101, party_id: 1),
        {:player, 102} => player(102, party_id: 1),
        {:mob, 200} => mob(200),
        {:mob, 201} => mob(201, is_dead: true)
      })

      %{target?: target?} = WzQuagmire.field_support(group([]))

      assert target?.({:mob, 200})
      refute target?.({:player, 100})
      refute target?.({:player, 102})
      refute target?.({:mob, 201})
    end
  end

  describe "manager-backed support" do
    test "a second field never restarts a held status; the status outlives the field it came from" do
      test_pid = self()
      stub(Catalog, :ground_module_for, fn :wz_quagmire -> {:ok, WzQuagmire} end)
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)
      stub_unit_registry(%{{:player, 100} => player(100), {:mob, 200} => mob(200)})

      stub(StatusInterpreter, :apply_status, fn _type, _id, _status, params ->
        send(test_pid, {:apply, params})
        StatusStorage.apply_status(:mob, 200, :sc_quagmire, params)
        :ok
      end)

      stub(StatusInterpreter, :remove_status, fn _type, _id, _status ->
        send(test_pid, :remove)
        StatusStorage.remove_status(:mob, 200, :sc_quagmire)
        :ok
      end)

      manager =
        start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

      allow(Catalog, self(), manager)
      allow(SpatialIndex, self(), manager)
      allow(StatusInterpreter, self(), manager)
      allow(UnitRegistry, self(), manager)

      :ok = Manager.register(manager, live_group(created_at: 0, expires_at: 10_000))

      assert_received {:apply, first_params}
      assert first_params[:level] == 1
      assert first_params[:val2] == 10
      assert first_params[:duration] == 10_000

      :ok = Manager.register(manager, live_group(group_id: 2, level: 5, expires_at: 25_000))
      refute_received {:apply, _}
      assert %{val1: 1, val2: 10} = StatusStorage.get_status(:mob, 200, :sc_quagmire)

      :ok = Manager.destroy(manager, 1)
      refute_received :remove
      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)

      :ok = Manager.destroy(manager, 2)
      refute_received :remove
      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)
    end
  end

  describe "manager trigger and lifecycle flow" do
    test "grants a mob through on_touch, excludes players, and lets the mob keep it on on_out" do
      stub(Catalog, :ground_module_for, fn :wz_quagmire -> {:ok, WzQuagmire} end)
      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, 0 -> [] end)

      stub_unit_registry(%{
        {:player, 100} => player(100),
        {:player, 101} => player(101),
        {:mob, 200} => mob(200)
      })

      stub_status_interpreter()
      manager = start_manager()

      :ok = Manager.register(manager, live_group())
      assert :ok = Manager.trigger(manager, 1, {:player, 101}, :on_touch)
      assert :ok = Manager.trigger(manager, 1, {:mob, 200}, :on_touch)

      refute StatusStorage.has_status?(:player, 101, :sc_quagmire)
      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)

      assert :ok = Manager.trigger(manager, 1, {:mob, 200}, :on_out)

      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)
    end

    test "natural expiry keeps a monster's Quagmire while removing the field" do
      stub(Catalog, :ground_module_for, fn :wz_quagmire -> {:ok, WzQuagmire} end)
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)
      stub_unit_registry(%{{:player, 100} => player(100), {:mob, 200} => mob(200)})
      stub_status_interpreter()
      manager = start_manager()

      :ok = Manager.register(manager, live_group(next_tick_at: 1_000, expires_at: 2_000))
      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)

      assert :ok = Manager.tick(manager, 2_000)
      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)
      assert Storage.get(1) == nil
    end

    test "expires the field when its caster changes maps; the monster keeps its Quagmire" do
      stub(Catalog, :ground_module_for, fn :wz_quagmire -> {:ok, WzQuagmire} end)
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)
      stub_unit_registry(%{{:player, 100} => player(100), {:mob, 200} => mob(200)})
      stub_status_interpreter()
      manager = start_manager()

      :ok = Manager.register(manager, live_group())
      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)

      assert :ok = Lifecycle.publish_transition(:player, 100, "prontera", "geffen")
      assert :ok = Manager.tick(manager, 0)

      assert Storage.get(1) == nil
      assert StatusStorage.has_status?(:mob, 200, :sc_quagmire)
    end
  end

  defp group(attrs) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 92,
        skill_name: :wz_quagmire,
        level: 1,
        caster_id: 100,
        caster_type: :player,
        map_name: "prontera",
        center: {10, 20}
      },
      attrs
    )
  end

  defp live_group(attrs \\ []) do
    group(
      Keyword.merge(
        [
          cells: [{10, 20}],
          created_at: 0,
          next_tick_at: 1_000,
          expires_at: 10_000,
          interval: 1_000
        ],
        attrs
      )
    )
  end

  defp start_manager do
    manager =
      start_supervised!(
        {Manager,
         name: nil,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _type, _id, _map -> true end}
      )

    allow(Catalog, self(), manager)
    allow(SpatialIndex, self(), manager)
    allow(StatusInterpreter, self(), manager)
    allow(UnitRegistry, self(), manager)
    manager
  end

  defp stub_status_interpreter do
    stub(StatusInterpreter, :apply_status, fn unit_type, unit_id, status_type, params ->
      StatusStorage.apply_status(unit_type, unit_id, status_type, params)
      :ok
    end)

    stub(StatusInterpreter, :remove_status, fn unit_type, unit_id, status_type ->
      StatusStorage.remove_status(unit_type, unit_id, status_type)
      :ok
    end)
  end

  defp stub_unit_registry(units) do
    stub(UnitRegistry, :get_unit, fn type, id ->
      case Map.fetch(units, {type, id}) do
        {:ok, state} -> {:ok, {__MODULE__, state, self()}}
        :error -> {:error, :not_found}
      end
    end)
  end

  defp player(id, attrs \\ []) do
    struct(
      PlayerState,
      Map.merge(
        %{
          character_id: id,
          map_name: "prontera",
          party_id: 0,
          guild_id: 0,
          action_state: :idle,
          stats: %{current_state: %{hp: 100}}
        },
        Map.new(attrs)
      )
    )
  end

  defp mob(id, attrs \\ []) do
    struct(
      MobState,
      Map.merge(%{instance_id: id, map_name: "prontera", hp: 100, is_dead: false}, Map.new(attrs))
    )
  end
end
