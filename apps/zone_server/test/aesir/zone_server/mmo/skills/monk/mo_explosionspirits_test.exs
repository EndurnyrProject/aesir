defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoExplosionspiritsTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoExplosionspirits
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "declares Fury's verified costs and duration" do
    assert {:ok, definition} = Catalog.by_id(270)
    assert definition.name == :mo_explosionspirits
    assert definition.status == :sc_explosionspirits
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.max_level == 5
    assert definition.sp_cost == List.duplicate(15, 5)
    assert definition.sphere_cost == List.duplicate(5, 5)
    assert definition.duration == List.duplicate(180_000, 5)
  end

  test "applies Fury with its level and 180-second duration" do
    caster = %{character_id: 1000}
    definition = MoExplosionspirits.definition()

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_explosionspirits, params ->
      assert params == [val1: 3, caster_id: 1000, duration: 180_000]
      :ok
    end)

    assert {:ok, ^caster} = MoExplosionspirits.cast(caster, :self, 3, definition)
  end

  test "propagates Fury application failures" do
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_explosionspirits, _params ->
      {:error, :conflict}
    end)

    assert {:error, :conflict} =
             MoExplosionspirits.cast(caster, :self, 1, MoExplosionspirits.definition())
  end
end
