defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TrapStateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState

  test "defaults to an unpaid armed trap" do
    assert {:ok,
            %TrapState{
              phase: :armed,
              reclaim_item_id: nil,
              claymore_spendable?: false,
              natural_expiry: :drop_item,
              return_item_on_expiry?: false,
              link_id: nil
            }} = TrapState.new()
  end

  test "accepts every lifecycle phase and natural-expiry policy" do
    for phase <- [:armed, :used, :sprung, :captured],
        natural_expiry <- [:drop_item, :become_used] do
      assert {:ok, %TrapState{phase: ^phase, natural_expiry: ^natural_expiry}} =
               TrapState.new(%{phase: phase, natural_expiry: natural_expiry})
    end
  end

  test "rejects invalid lifecycle metadata" do
    assert {:error, :invalid_trap_state} = TrapState.new(%{phase: :invalid})
    assert {:error, :invalid_trap_state} = TrapState.new(%{natural_expiry: :remove})
    assert {:error, :invalid_trap_state} = TrapState.new(%{reclaim_item_id: 0})
    assert {:error, :invalid_trap_state} = TrapState.new(%{link_id: -1})
  end

  test "rejects unknown keys instead of silently dropping typos" do
    assert {:error, :invalid_trap_state} = TrapState.new(%{claymore_spendable: true})
  end
end
