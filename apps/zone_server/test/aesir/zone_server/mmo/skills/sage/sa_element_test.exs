defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaElementTest do
  @moduledoc """
  The four `SA_ELEMENT*` converter skills.

  The metadata block is asserted against `db/re/skill_db.yml`, and the cast
  exercises the real status storage plus `MobState.to_combatant/1`, so an
  override that never reaches the damage pipeline fails here.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaElementfire
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaElementground
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaElementwater
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaElementwind
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @mob_instance_id 4001
  @caster_id 1000

  # {module, skill id, skill name, endowed element, converter item id}
  @skills [
    {SaElementwater, 1008, :sa_elementwater, :water, 12_115},
    {SaElementground, 1017, :sa_elementground, :earth, 12_116},
    {SaElementfire, 1018, :sa_elementfire, :fire, 12_114},
    {SaElementwind, 1019, :sa_elementwind, :wind, 12_117}
  ]

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    Mimic.copy(CriticalHits)
    Mimic.copy(ElementModifiers)

    stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
      %{damage: damage, is_critical: false}
    end)

    stub(ElementModifiers, :get_modifier, fn attack_element,
                                             defense_element,
                                             defense_level,
                                             ratio_bonus ->
      send(self(), {:defense_element, defense_element, defense_level})

      call_original(ElementModifiers, :get_modifier, [
        attack_element,
        defense_element,
        defense_level,
        ratio_bonus
      ])
    end)

    :ok
  end

  defp caster, do: %PlayerState{character_id: @caster_id}

  defp definition(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition
  end

  defp build_mob(modes) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(@mob_instance_id, mob_data, spawn_ref, "prontera", 100, 100)
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    state
  end

  defp attack(mob_state) do
    attacker = CombatTestHelper.create_player_combatant(str: 50)
    defender = MobState.to_combatant(mob_state)

    assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender)
  end

  describe "metadata" do
    for {module, id, name, element, item_id} <- @skills do
      test "#{name} matches the rAthena renewal table" do
        assert {:ok, %{name: unquote(name)}} = Catalog.by_id(unquote(id))
        assert {:ok, unquote(module)} = Catalog.active_module_for(unquote(name))

        definition = definition(unquote(name))

        assert definition.max_level == 1
        assert definition.damage_type == :no_damage
        assert definition.target_type == :target_enemy
        assert definition.element == unquote(element)
        assert definition.range == 9
        assert definition.sp_cost == [30]
        assert definition.cast_time == []
        assert definition.fixed_cast_time == [2_000]
        assert definition.after_cast_delay == [1_000]
        assert definition.duration == [1_800_000]
        assert definition.status == :sc_elementalchange
        assert definition.item_cost == [%{id: unquote(item_id), amount: 1}]
      end
    end
  end

  describe "cast/4 on a monster" do
    for {module, _id, name, element, _item_id} <- @skills do
      test "#{name} overrides the mob's defense element to #{element}" do
        mob = build_mob([:aggressive])

        assert {:ok, %PlayerState{}} =
                 unquote(module).cast(
                   caster(),
                   {:unit, @mob_instance_id},
                   1,
                   definition(unquote(name))
                 )

        attack(mob)

        assert_received {:defense_element, unquote(element), 1}
      end
    end
  end

  describe "cast/4 on a boss-moded monster" do
    test "leaves the mob's native element alone" do
      mob = build_mob([:boss])

      assert {:ok, %PlayerState{}} =
               SaElementwater.cast(
                 caster(),
                 {:unit, @mob_instance_id},
                 1,
                 definition(:sa_elementwater)
               )

      refute StatusStorage.has_status?(:mob, @mob_instance_id, :sc_elementalchange)

      attack(mob)

      assert_received {:defense_element, :neutral, 1}
    end
  end

  describe "cast/4 on a non-monster target" do
    test "applies nothing when the target id is not a live mob" do
      assert {:ok, %PlayerState{}} =
               SaElementwater.cast(caster(), {:unit, 9999}, 1, definition(:sa_elementwater))

      refute StatusStorage.has_status?(:mob, 9999, :sc_elementalchange)
    end
  end
end
