defmodule Aesir.ZoneServer.Mmo.Skills.TfDetoxifyTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.TfDetoxify
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.by_id/1 resolves TF_DETOXIFY" do
    assert {:ok, definition} = Catalog.by_id(53)
    assert definition.name == :tf_detoxify
    assert definition.max_level == 1
    assert definition.target_type == :target_ally
    assert definition.range == 9
    assert definition.sp_cost == [10]
  end

  test "cast/4 removes sc_poison and sc_dpoison from a targeted ally" do
    {:ok, definition} = Catalog.by_id(53)
    caster = %{character_id: 1000}
    target_id = 2000

    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_poison -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_dpoison -> :ok end)

    assert {:ok, ^caster} = TfDetoxify.cast(caster, {:unit, target_id}, 1, definition)
  end

  test "cast/4 removes both statuses on :self" do
    {:ok, definition} = Catalog.by_id(53)
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_poison -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_dpoison -> :ok end)

    assert {:ok, ^caster} = TfDetoxify.cast(caster, :self, 1, definition)
  end

  test "cast/4 still returns {:ok, caster} on a clean target (remove_status is a no-op)" do
    {:ok, definition} = Catalog.by_id(53)
    caster = %{character_id: 1000}
    target_id = 3000

    stub(StatusInterpreter, :remove_status, fn :player, ^target_id, _status -> :ok end)

    assert {:ok, ^caster} = TfDetoxify.cast(caster, {:unit, target_id}, 1, definition)
  end
end
