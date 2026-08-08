defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaVolcanoTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Sage.ElementField
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaDeluge
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaLandprotector
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaVolcano
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    player = %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 100}}}
    mob = struct(MobState, %{hp: 100, is_dead: false})

    :ok = UnitRegistry.register_unit(:player, 100, __MODULE__, %{player | character_id: 100})
    :ok = UnitRegistry.register_unit(:player, 101, __MODULE__, %{player | character_id: 101})
    :ok = UnitRegistry.register_unit(:mob, 200, __MODULE__, %{mob | instance_id: 200})
    :ok
  end

  # rAthena db/re/skill_db.yml:5768-5817.
  describe "definition/0" do
    test "matches the Renewal Volcano level tables" do
      definition = SaVolcano.definition()

      assert definition.id == 285
      assert definition.max_level == 5
      assert definition.target_type == :ground
      assert definition.damage_type == :no_damage
      assert definition.range == 2
      assert definition.element == :fire
      assert definition.sp_cost == [48, 46, 44, 42, 40]
      assert definition.cast_time == List.duplicate(4_000, 5)
      assert definition.fixed_cast_time == List.duplicate(1_000, 5)
      assert definition.item_cost == [%{id: 717, amount: 1}]
      assert definition.unit_duration == [60_000, 120_000, 180_000, 240_000, 300_000]
    end
  end

  describe "on_place/1" do
    test "creates the 7x7 layout-radius-3 field at every level" do
      for level <- 1..5 do
        assert {:ok, placement} = SaVolcano.on_place(group(level: level))

        assert Enum.sort(placement.cells) == Enum.sort(for(x <- 7..13, y <- 17..23, do: {x, y}))
        assert length(placement.cells) == 49
        assert placement.duration == 60_000 * level
        assert placement.path_check
      end
    end
  end

  # rAthena src/map/skill.cpp:6517-6525 applies the status to any bl on the field.
  describe "field_support/1" do
    test "grants the level as val1 at every level" do
      for level <- 1..5 do
        assert %{status_type: :sc_volcano, params: params} =
                 SaVolcano.field_support(group(level: level))

        assert params == [level: level, val1: level]
      end
    end

    test "targets every unit, including the caster, with no enemy filter" do
      %{target?: target?} = SaVolcano.field_support(group(level: 1))

      assert target?.({:player, 100})
      assert target?.({:player, 101})
      assert target?.({:mob, 200})
    end
  end

  describe "manager-backed field support" do
    setup do
      stub(Catalog, :ground_module_for, fn :sa_volcano -> {:ok, SaVolcano} end)
      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, 0 -> [] end)
      stub_status_interpreter()
      {:ok, manager: start_manager()}
    end

    test "acquires on entry and releases on exit for a player occupant", %{manager: manager} do
      :ok = Manager.register(manager, live_group())

      assert :ok = Manager.trigger(manager, 1, {:player, 101}, :on_touch)
      assert FieldSupport.supported?(:player, 101, :sc_volcano)

      assert :ok = Manager.trigger(manager, 1, {:player, 101}, :on_out)
      refute FieldSupport.supported?(:player, 101, :sc_volcano)
    end

    test "acquires on entry and releases on exit for a mob occupant", %{manager: manager} do
      :ok = Manager.register(manager, live_group())

      assert :ok = Manager.trigger(manager, 1, {:mob, 200}, :on_touch)
      assert FieldSupport.supported?(:mob, 200, :sc_volcano)

      assert :ok = Manager.trigger(manager, 1, {:mob, 200}, :on_out)
      refute FieldSupport.supported?(:mob, 200, :sc_volcano)
    end

    test "supports the caster standing in their own field", %{manager: manager} do
      :ok = Manager.register(manager, live_group())

      assert :ok = Manager.trigger(manager, 1, {:player, 100}, :on_touch)
      assert FieldSupport.supported?(:player, 100, :sc_volcano)
    end

    # rAthena skill_db.yml gives the field Interval: -1, so it never ticks.
    test "registers tickless and survives a tick that would otherwise be due", %{
      manager: manager
    } do
      :ok = Manager.register(manager, live_group())

      assert %Group{next_tick_at: nil} = Storage.get(1)

      assert :ok = Manager.tick(manager, 60_000)
      assert %Group{next_tick_at: nil} = Storage.get(1)
    end

    test "releases support when the field expires", %{manager: manager} do
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)

      :ok = Manager.register(manager, live_group(expires_at: 2_000))
      assert FieldSupport.supported?(:mob, 200, :sc_volcano)

      assert :ok = Manager.tick(manager, 2_000)

      assert Storage.get(1) == nil
      refute FieldSupport.supported?(:mob, 200, :sc_volcano)
    end
  end

  # rAthena src/map/skill.cpp:5883-5907: the caster's previous element field is
  # cleared, and a swap between the trio reuses its remaining duration.
  describe "element field family exclusivity" do
    setup do
      stub(Catalog, :ground_module_for, fn
        :sa_volcano -> {:ok, SaVolcano}
        :sa_deluge -> {:ok, SaDeluge}
        :sa_landprotector -> {:ok, SaLandprotector}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn _map, _x, _y, 0 -> [] end)
      stub_status_interpreter()
      {:ok, manager: start_manager()}
    end

    test "replaces the caster's own field when swapping element", %{manager: manager} do
      :ok = Manager.register(manager, live_group())
      :ok = Manager.register(manager, deluge_group())

      assert Storage.get(1) == nil
      assert %Group{skill_name: :sa_deluge} = Storage.get(2)
    end

    test "leaves a different caster's field alone", %{manager: manager} do
      :ok = Manager.register(manager, live_group())
      :ok = Manager.register(manager, deluge_group(caster_id: 101))

      assert %Group{skill_name: :sa_volcano} = Storage.get(1)
      assert %Group{skill_name: :sa_deluge} = Storage.get(2)
    end

    test "inherits the replaced field's remaining duration, never refreshing it", %{
      manager: manager
    } do
      :ok = Manager.register(manager, live_group(expires_at: 10_000))
      :ok = Manager.register(manager, deluge_group(expires_at: 61_000))

      assert %Group{expires_at: 10_000} = Storage.get(2)
    end

    test "recasting the same element does not refresh the duration", %{manager: manager} do
      :ok = Manager.register(manager, live_group(expires_at: 10_000))
      :ok = Manager.register(manager, live_group(group_id: 2, expires_at: 61_000))

      assert Storage.get(1) == nil
      assert %Group{expires_at: 10_000} = Storage.get(2)
    end

    test "falls back to the full duration when the replaced field already expired", %{
      manager: manager
    } do
      :ok = Manager.register(manager, live_group(expires_at: 500))
      :ok = Manager.register(manager, deluge_group(expires_at: 61_000))

      assert %Group{expires_at: 61_000} = Storage.get(2)
    end

    test "releases the replaced field's support", %{manager: manager} do
      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 10, 20, 0 -> [{:mob, 200}] end)

      :ok = Manager.register(manager, live_group())
      assert FieldSupport.supported?(:mob, 200, :sc_volcano)

      :ok = Manager.register(manager, deluge_group())

      refute FieldSupport.supported?(:mob, 200, :sc_volcano)
      assert FieldSupport.supported?(:mob, 200, :sc_deluge)
    end

    test "Land Protector inherits the replaced element field's remaining duration", %{
      manager: manager
    } do
      # Placing Land Protector over your own element field takes over the field's
      # remaining time (rAthena skill.cpp:5883-5902): the trio opts into
      # inherit_family_duration, and inheritance keys on the replaced field.
      :ok = Manager.register(manager, live_group(expires_at: 10_000))

      :ok =
        Manager.register(
          manager,
          group(
            group_id: 2,
            skill_id: 288,
            skill_name: :sa_landprotector,
            cells: [{30, 40}],
            center: {30, 40},
            expires_at: 166_000,
            visibility: :public,
            lifecycle_policy: ElementField.policy()
          )
        )

      assert Storage.get(1) == nil
      assert %Group{expires_at: 10_000} = Storage.get(2)
    end

    test "an element field placed over an existing Land Protector gets a fresh duration", %{
      manager: manager
    } do
      # Land Protector does not opt into inherit_family_duration, so it does not
      # pass its remaining time on to a trio field that replaces it.
      :ok =
        Manager.register(
          manager,
          group(
            group_id: 1,
            skill_id: 288,
            skill_name: :sa_landprotector,
            cells: [{10, 20}],
            center: {10, 20},
            expires_at: 10_000,
            visibility: :public,
            lifecycle_policy: ElementField.policy()
          )
        )

      :ok = Manager.register(manager, deluge_group(expires_at: 61_000))

      assert Storage.get(1) == nil
      assert %Group{expires_at: 61_000} = Storage.get(2)
    end
  end

  defp group(attrs) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 285,
        skill_name: :sa_volcano,
        level: 1,
        caster_id: 100,
        caster_type: :player,
        map_name: "prontera",
        center: {10, 20},
        interval: 1_000
      },
      attrs
    )
  end

  defp live_group(attrs \\ []) do
    group(
      Keyword.merge(
        [
          cells: [{10, 20}],
          expires_at: 61_000,
          visibility: :public,
          lifecycle_policy: ElementField.policy(true)
        ],
        attrs
      )
    )
  end

  defp deluge_group(attrs \\ []) do
    live_group(Keyword.merge([group_id: 2, skill_id: 286, skill_name: :sa_deluge], attrs))
  end

  defp start_manager do
    manager =
      start_supervised!(
        {Manager,
         name: nil,
         clock: fn -> 1_000 end,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _type, _id, _map -> true end}
      )

    allow(Catalog, self(), manager)
    allow(SpatialIndex, self(), manager)
    allow(StatusInterpreter, self(), manager)
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
end
