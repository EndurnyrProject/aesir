defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdSiegfriedTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdSiegfried

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(Perform)
    :ok
  end

  test "declares the pinned Siegfried skill data" do
    definition = BdSiegfried.definition()

    assert definition.id == 313
    assert definition.name == :bd_siegfried
    assert definition.display_name == "Acoustic Rhythm"
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :misc
    assert definition.splash_radius == 15
    assert definition.hit_count == 1
    assert definition.sp_cost == [40, 44, 48, 52, 56]
    assert definition.duration == List.duplicate(180_000, 5)
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == List.duplicate(500, 5)
    assert definition.after_cast_delay == List.duplicate(300, 5)
    assert definition.cooldown == List.duplicate(20_000, 5)
    assert definition.require_weapon == [:musical, :whip]
    assert BdSiegfried.__skill_capabilities__() == [:active, :ensemble]
  end

  test "delegates party application with effective-level magnitudes" do
    caster = %{character_id: 313}
    definition = BdSiegfried.definition()

    expect(Perform, :perform, fn
      ^caster, ^definition, 3, :sc_siegfried, params_fun, [scope: :party] ->
        assert params_fun.(4) == [val1: 12, val2: 20]
        {:ok, caster}
    end)

    assert {:ok, ^caster} = BdSiegfried.cast(caster, :self, 3, definition)
  end
end
