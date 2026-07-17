defmodule Aesir.ZoneServer.Mmo.Skills.WzQuagmireTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.WzQuagmire
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(UnitRegistry)
    :ok
  end

  # rAthena db/re/skill_db.yml:3791-3850 and src/map/status.cpp:11643-11645.
  describe "definition/0" do
    test "matches the Renewal Quagmire level tables" do
      definition = WzQuagmire.definition()

      assert definition.id == 92
      assert definition.max_level == 5
      assert definition.target_type == :ground
      assert definition.damage_type == :no_damage
      assert definition.range == 9
      assert definition.element == :earth
      assert definition.sp_cost == [5, 10, 15, 20, 25]
      assert definition.after_cast_delay == List.duplicate(1_000, 5)
      assert definition.unit_duration == [5_000, 10_000, 15_000, 20_000, 25_000]
    end
  end

  describe "on_place/1" do
    test "creates the canonical 3x3 field and reconciliation cadence" do
      assert {:ok, placement} = WzQuagmire.on_place(group(level: 5))

      assert Enum.sort(placement.cells) ==
               Enum.sort(for(x <- 9..11, y <- 19..21, do: {x, y}))

      assert placement.interval == 1_000
      assert placement.initial_delay == 0
      assert placement.duration == 25_000
      assert placement.lifecycle_policy.max_instances_per_caster == 3
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
    test "seeds enemies and preserves overlapping support until its final field expires" do
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

      :ok =
        Manager.register(
          manager,
          group(cells: [{10, 20}], next_tick_at: 1_000, expires_at: 10_000, interval: 1_000)
        )

      assert FieldSupport.sources(:mob, 200, :sc_quagmire) == [[level: 1, val1: 1, val2: 10]]
      assert_received {:apply, first_params}
      assert first_params[:level] == 1
      assert first_params[:val2] == 10

      :ok =
        Manager.register(
          manager,
          group(
            group_id: 2,
            level: 5,
            cells: [{10, 20}],
            next_tick_at: 1_000,
            expires_at: 10_000,
            interval: 1_000
          )
        )

      assert Enum.sort(FieldSupport.sources(:mob, 200, :sc_quagmire)) ==
               Enum.sort([
                 [level: 1, val1: 1, val2: 10],
                 [level: 5, val1: 5, val2: 50]
               ])

      assert_received {:apply, second_params}
      assert second_params[:level] == 5
      assert second_params[:val2] == 50

      :ok = Manager.destroy(manager, 1)

      assert FieldSupport.sources(:mob, 200, :sc_quagmire) == [[level: 5, val1: 5, val2: 50]]
      assert_received {:apply, retained_params}
      assert retained_params[:level] == 5
      assert retained_params[:val2] == 50
      refute_received :remove

      :ok = Manager.destroy(manager, 2)

      assert FieldSupport.sources(:mob, 200, :sc_quagmire) == []
      assert_received :remove
    end
  end

  describe "manager trigger and lifecycle flow" do
    test "acquires and releases mob support through on_touch and on_out while excluding players" do
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

      refute FieldSupport.supported?(:player, 101, :sc_quagmire)
      assert FieldSupport.supported?(:mob, 200, :sc_quagmire)

      assert :ok = Manager.trigger(manager, 1, {:mob, 200}, :on_out)

      refute FieldSupport.supported?(:mob, 200, :sc_quagmire)
    end

    test "reconciles a stationary occupant on its due tick and releases support at natural expiry" do
      stub(Catalog, :ground_module_for, fn :wz_quagmire -> {:ok, WzQuagmire} end)
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)
      stub_unit_registry(%{{:player, 100} => player(100), {:mob, 200} => mob(200)})
      stub_status_interpreter()
      manager = start_manager()

      :ok = Manager.register(manager, live_group(next_tick_at: 1_000, expires_at: 2_000))
      :ok = FieldSupport.release(:mob, 200, :sc_quagmire, 1)
      refute FieldSupport.supported?(:mob, 200, :sc_quagmire)

      assert :ok = Manager.tick(manager, 1_000)
      assert FieldSupport.supported?(:mob, 200, :sc_quagmire)

      assert :ok = Manager.tick(manager, 2_000)
      refute FieldSupport.supported?(:mob, 200, :sc_quagmire)
      assert Storage.get(1) == nil
    end

    test "skips field support acquisition when interval occupants are unchanged" do
      test_pid = self()
      {:ok, sources} = Agent.start_link(fn -> [] end)
      Mimic.copy(FieldSupport)
      stub(Catalog, :ground_module_for, fn :wz_quagmire -> {:ok, WzQuagmire} end)
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)
      stub_unit_registry(%{{:player, 100} => player(100), {:mob, 200} => mob(200)})

      stub(FieldSupport, :acquire, fn type, id, status, _group_id, params ->
        Agent.update(sources, &[{type, id, status, params} | &1])
        send(test_pid, :acquire)
        :ok
      end)

      stub(FieldSupport, :sources_for_group, fn _group_id ->
        Agent.get(sources, & &1)
      end)

      manager = start_manager()
      allow(FieldSupport, self(), manager)

      assert :ok = Manager.register(manager, live_group(next_tick_at: 1_000))
      assert_received :acquire

      assert :ok = Manager.tick(manager, 1_000)
      refute_received :acquire
    end

    test "expires the field and releases its support when its caster changes maps" do
      stub(Catalog, :ground_module_for, fn :wz_quagmire -> {:ok, WzQuagmire} end)
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)
      stub_unit_registry(%{{:player, 100} => player(100), {:mob, 200} => mob(200)})
      stub_status_interpreter()
      manager = start_manager()

      :ok = Manager.register(manager, live_group())
      assert FieldSupport.supported?(:mob, 200, :sc_quagmire)

      assert :ok = Lifecycle.publish_transition(:player, 100, "prontera", "geffen")
      assert :ok = Manager.tick(manager, 0)

      assert Storage.get(1) == nil
      refute FieldSupport.supported?(:mob, 200, :sc_quagmire)
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
        [cells: [{10, 20}], next_tick_at: 1_000, expires_at: 10_000, interval: 1_000],
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

  defp player(id, attrs \\ []),
    do: Map.merge(%{character_id: id, party_id: 0, guild_id: 0}, Map.new(attrs))

  defp mob(id, attrs \\ []), do: Map.merge(%{instance_id: id, is_dead: false}, Map.new(attrs))
end
