defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.EffectsTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  @caster_id 48_001
  @group %Group{group_id: 9, skill_name: :pa_gospel, caster_id: @caster_id, caster_type: :player}

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Dispel)
    Mimic.copy(DamageApplication)
    Mimic.copy(SkillAttack)
    :ok
  end

  test "the blessing table has 13 entries and the affliction table 10, all on known statuses" do
    assert length(Effects.bless_table()) == 13
    assert length(Effects.afflict_table()) == 10

    for entry <- Effects.bless_table() ++ Effects.afflict_table(),
        status_id <- status_ids(entry) do
      assert Registry.get_definition(status_id), "unknown status #{status_id}"
    end
  end

  test "the tables carry the reference values and durations" do
    assert {:status, :sc_scresist, 100, 60_000} in Effects.bless_table()
    assert {:status, :sc_incmhprate, 100, 60_000} in Effects.bless_table()
    assert {:status, :sc_incallstatus, 20, 60_000} in Effects.bless_table()
    assert {:status, :sc_blessing, 10, 240_000} in Effects.bless_table()
    assert {:status, :sc_increaseagi, 10, 240_000} in Effects.bless_table()
    assert {:status, :sc_incdefrate, 25, 10_000} in Effects.bless_table()
    assert {:status_pair, {:sc_inchit, 50}, {:sc_incflee, 50}, 60_000} in Effects.bless_table()

    assert {:damage, :def_reduced, 3_000..7_999} in Effects.afflict_table()
    assert {:damage, :flat, 1_500..5_499} in Effects.afflict_table()
    assert {:status, :sc_curse, 1, 1_800_000} in Effects.afflict_table()
    assert {:status, :sc_provoke, 10, 1_800_000} in Effects.afflict_table()
    assert {:status, :sc_incdefrate, -100, 20_000} in Effects.afflict_table()
    assert {:status, :sc_incfleerate, -100, 20_000} in Effects.afflict_table()
    assert {:status, :sc_gospel_slow, 1, 20_000} in Effects.afflict_table()
  end

  describe "def_reduced/2" do
    @tag game_mode: :renewal
    test "renewal subtracts hard and soft DEF flat" do
      assert Effects.def_reduced(5_000, defender(100, 50)) == 4_850
      assert Effects.def_reduced(100, defender(100, 50)) == 0
    end

    @tag game_mode: :pre_renewal
    test "classic takes hard DEF as a percentage then subtracts soft DEF" do
      assert Effects.def_reduced(5_000, defender(10, 50)) == 4_450
      assert Effects.def_reduced(5_000, defender(100, 50)) == 0
    end
  end

  describe "apply/4" do
    test "a status blessing is applied with the group's caster identity" do
      expect(Interpreter, :apply_status, fn :player, 7, :sc_incatkrate, params ->
        assert params[:val1] == 100
        assert params[:duration] == 60_000
        assert params[:caster_id] == @caster_id
        assert params[:source_type] == :player
        :ok
      end)

      assert :ok =
               Effects.apply(
                 {:status, :sc_incatkrate, 100, 60_000},
                 @group,
                 nil,
                 {:player, 7}
               )
    end

    test "a status pair applies both statuses" do
      expect(Interpreter, :apply_status, fn :player, 7, :sc_inchit, params ->
        assert params[:val1] == 50
        :ok
      end)

      expect(Interpreter, :apply_status, fn :player, 7, :sc_incflee, params ->
        assert params[:val1] == 50
        :ok
      end)

      assert :ok =
               Effects.apply(
                 {:status_pair, {:sc_inchit, 50}, {:sc_incflee, 50}, 60_000},
                 @group,
                 nil,
                 {:player, 7}
               )
    end

    test "the heal blessing rolls 1000-9999 and heals through the damage application path" do
      expect(DamageApplication, :apply_heal, fn :player, 7, amount, @caster_id ->
        assert amount in 1_000..9_999
        :ok
      end)

      assert :ok = Effects.apply({:heal, 1_000..9_999}, @group, nil, {:player, 7})
    end

    test "the cleanse blessing dispels debuffs only" do
      expect(Dispel, :dispel_debuffs, fn {:player, 7} -> :ok end)
      assert :ok = Effects.apply(:cleanse, @group, nil, {:player, 7})
    end

    test "damage afflictions strike through the field misc path" do
      caster_state = %{character_id: @caster_id}
      group = %{@group | level: 4}

      expect(SkillAttack, :execute_field_misc_attack, fn ^caster_state,
                                                         {:mob, 42},
                                                         ^group,
                                                         opts ->
        assert opts[:skill_id] == 369
        assert opts[:skill_level] == 4
        assert opts[:element] == :neutral
        assert opts[:base_damage] in 1_500..5_499
        :ok
      end)

      assert :ok =
               Effects.apply(
                 {:damage, :flat, 1_500..5_499},
                 group,
                 caster_state,
                 {:mob, 42}
               )
    end
  end

  @tag game_mode: :renewal
  test "the DEF-reduced affliction resolves the target's combatant before striking" do
    caster_state = %{character_id: @caster_id}
    group = %{@group | level: 1}
    stub(Combat, :resolve_combatant, fn :mob, 42 -> {:ok, defender(100, 50)} end)

    expect(SkillAttack, :execute_field_misc_attack, fn ^caster_state, {:mob, 42}, ^group, opts ->
      assert opts[:base_damage] in (3_000 - 150)..(7_999 - 150)
      :ok
    end)

    assert :ok =
             Effects.apply({:damage, :def_reduced, 3_000..7_999}, group, caster_state, {:mob, 42})
  end

  test "a Gospel group is an authorised field source for its damage afflictions" do
    group = %{@group | skill_id: 369, level: 1, map_name: "prontera"}
    caster = %{unit_type: :player, unit_id: @caster_id, map_name: "prontera", party_id: 0}
    target = %{unit_type: :mob, unit_id: 42, map_name: "prontera", hp: 100, mob_id: 1002}

    assert :ok = Targeting.validate_field_target(group, caster, target)
  end

  @tag game_mode: :renewal
  test "a DEF-reduced roll floored to zero strikes nothing" do
    stub(Combat, :resolve_combatant, fn :mob, 42 -> {:ok, defender(10_000, 0)} end)
    reject(&SkillAttack.execute_field_misc_attack/4)

    assert :ok =
             Effects.apply(
               {:damage, :def_reduced, 3_000..7_999},
               %{@group | level: 1},
               %{},
               {:mob, 42}
             )
  end

  defp defender(hard, soft), do: %{combat_stats: %{def: hard, soft_def: soft}}

  defp status_ids({:status, id, _val, _duration}), do: [id]
  defp status_ids({:status_pair, {a, _}, {b, _}, _duration}), do: [a, b]
  defp status_ids(_other), do: []
end
