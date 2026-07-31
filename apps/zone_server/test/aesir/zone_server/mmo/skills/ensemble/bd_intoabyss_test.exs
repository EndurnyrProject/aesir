defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdIntoabyssTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdIntoabyss
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IntoAbyss

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Into the Abyss data" do
    assert {:ok, BdIntoabyss} = Catalog.active_module_for(:bd_intoabyss)
    assert {:ok, definition} = Catalog.by_id(312)

    assert definition.name == :bd_intoabyss
    assert definition.display_name == "Into the Abyss"
    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :misc
    assert definition.hit_count == 1
    assert definition.splash_radius == 15
    assert definition.sp_cost == [70]
    assert definition.duration == [180_000]
    assert definition.cast_time == [1_000]
    assert definition.fixed_cast_time == [500]
    assert definition.after_cast_delay == [300]
    assert definition.cooldown == [20_000]
    assert definition.require_weapon == [:musical, :whip]
    assert definition.item_cost == []
    assert definition.unit_duration == []
    assert Catalog.ensemble?(312)
    refute function_exported?(BdIntoabyss, :dynamic_cost, 4)
  end

  test "status is registered as a finite, mutually-exclusive buff" do
    metadata = IntoAbyss.metadata()

    assert metadata.id == :sc_intoabyss
    assert metadata.properties == [:buff]
    assert metadata.calc_flags == []
    assert metadata.duration == 180_000
    assert metadata.no_dispel
    assert metadata.icon == :intoabyss

    assert metadata.end_on_start == [
             :sc_richmankim,
             :sc_eternalchaos,
             :sc_drumbattle,
             :sc_nibelungen,
             :sc_rokisweil,
             :sc_intoabyss,
             :sc_siegfried
           ]

    assert IntoAbyss in Effects.all()
  end
end
