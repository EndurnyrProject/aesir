defmodule Aesir.ZoneServer.Mmo.Skills.AlCureTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AlCure
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.by_id/1 resolves AL_CURE" do
    assert {:ok, def} = Catalog.by_id(35)
    assert def.name == :al_cure
    assert def.max_level == 1
    assert def.target_type == :target_ally
    assert def.sp_cost == [15]
    assert def.after_cast_delay == [1_000]
  end

  test "Catalog.by_name/1 resolves :al_cure" do
    assert {:ok, %{id: 35}} = Catalog.by_name(:al_cure)
  end

  test "cast/4 removes sc_silence, sc_blind, sc_confusion from a targeted ally" do
    {:ok, definition} = Catalog.by_id(35)
    caster = %{character_id: 1000}
    target_id = 2000

    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_silence -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_blind -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_confusion -> :ok end)

    assert {:ok, ^caster} = AlCure.cast(caster, {:unit, target_id}, 1, definition)
  end

  test "cast/4 removes all three statuses on :self" do
    {:ok, definition} = Catalog.by_id(35)
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_silence -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_blind -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_confusion -> :ok end)

    assert {:ok, ^caster} = AlCure.cast(caster, :self, 1, definition)
  end

  test "cast/4 still returns {:ok, caster} when statuses are absent (remove_status is a no-op)" do
    {:ok, definition} = Catalog.by_id(35)
    caster = %{character_id: 1000}
    target_id = 3000

    stub(StatusInterpreter, :remove_status, fn :player, ^target_id, _status -> :ok end)

    assert {:ok, ^caster} = AlCure.cast(caster, {:unit, target_id}, 1, definition)
  end
end
