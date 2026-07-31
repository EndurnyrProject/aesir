defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdDrumbattlefieldTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdDrumbattlefield
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DrumBattle
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  Mimic.copy(Perform)

  setup :verify_on_exit!

  setup do
    Catalog.reload()
    :ok
  end

  test "Drum of the Battlefield adds flat ATK and DEF at every pinned level" do
    for {level, expected_atk, expected_def} <- [{1, 20, 15}, {5, 40, 75}] do
      modifiers =
        DrumBattle.modifiers(%StatusEntry{type: :sc_drumbattle, val1: level, state: %{}}, %{})

      assert modifiers == %{atk: expected_atk, def: expected_def}
      refute Map.has_key?(modifiers, :atk_rate)
      refute Map.has_key?(modifiers, :def_rate)

      assert combat_delta(%{str: 0, vit: 0}, modifiers) == {expected_atk, expected_def}
      assert combat_delta(%{str: 100, vit: 100}, modifiers) == {expected_atk, expected_def}
    end
  end

  test "Drum of the Battlefield status has its pinned duration and mutual exclusion" do
    metadata = DrumBattle.metadata()

    assert metadata.duration == 180_000
    assert metadata.properties == [:buff]
    assert metadata.calc_flags == [:atk, :def]

    assert metadata.end_on_start == [
             :sc_richmankim,
             :sc_eternalchaos,
             :sc_drumbattle,
             :sc_nibelungen,
             :sc_rokisweil,
             :sc_intoabyss,
             :sc_siegfried
           ]
  end

  test "definition delegates the party snapshot at the effective level" do
    assert {:ok, BdDrumbattlefield} = Catalog.active_module_for(:bd_drumbattlefield)
    definition = BdDrumbattlefield.definition()

    assert definition.id == 309
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :misc
    assert definition.hit_count == 1
    assert definition.splash_radius == 15
    assert definition.range == 0
    assert definition.unit_duration == []
    assert definition.item_cost == []
    assert definition.sp_cost == [50, 54, 58, 62, 66]
    assert definition.duration == List.duplicate(180_000, 5)
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == List.duplicate(500, 5)
    assert definition.after_cast_delay == List.duplicate(300, 5)
    assert definition.cooldown == List.duplicate(20_000, 5)
    assert definition.require_weapon == [:musical, :whip]
    assert BdDrumbattlefield.__skill_capabilities__() == [:active, :ensemble]
    refute function_exported?(BdDrumbattlefield, :dynamic_cost, 4)

    caster = %{character_id: 1}

    expect(Perform, :perform, fn ^caster,
                                 ^definition,
                                 5,
                                 :sc_drumbattle,
                                 params_fun,
                                 [scope: :party] ->
      assert params_fun.(5) == [val1: 5]
      {:ok, caster}
    end)

    assert {:ok, ^caster} = BdDrumbattlefield.cast(caster, :self, 5, definition)
  end

  defp combat_delta(base_stats, modifiers) do
    baseline = combat_stats(base_stats, %{})
    buffed = combat_stats(base_stats, modifiers)

    {buffed.atk - baseline.atk, buffed.def - baseline.def}
  end

  defp combat_stats(base_stats, status_effects) do
    %Stats{
      base_stats: Map.merge(%{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0}, base_stats),
      progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
      derived_stats: %{max_hp: 1, max_sp: 1},
      equipment: %Equipment{},
      modifiers: %{equipment: %{}, status_effects: status_effects, job_bonuses: %{}}
    }
    |> Stats.calculate_combat_stats()
    |> Map.fetch!(:combat_stats)
  end
end
