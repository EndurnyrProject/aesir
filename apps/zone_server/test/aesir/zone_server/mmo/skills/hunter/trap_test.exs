defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.TrapTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap

  @stats %{dex: 10, int: 10, base_level: 10}

  defp group(caster_type, origin, paid_return? \\ false, skill_name \\ :ht_landmine) do
    %Group{
      group_id: 1,
      skill_name: skill_name,
      caster_id: 10,
      caster_type: caster_type,
      state: %{cast_origin: origin, paid_return?: paid_return?}
    }
  end

  test "dual-writes typed and legacy armed metadata" do
    state = Trap.place_state(1, @stats, group(:player, :direct))

    assert %TrapState{phase: :armed, reclaim_item_id: 1065} = state.trap
    assert %{armed: true, reclaimable: true, trap_item: 1065} = state
    assert state.ignore_land_protector
  end

  test "Land Mine and Blast Mine are eligible for Claymore spending" do
    for skill_name <- [:ht_landmine, :ht_blastmine] do
      state = Trap.place_state(1, @stats, group(:player, :normal, true, skill_name))
      assert state.trap.claymore_spendable?
    end
  end

  test "only normal player placements carry paid natural return" do
    for {caster_type, origin, paid_return?, expected} <- [
          {:player, :normal, true, true},
          {:player, :normal, false, false},
          {:player, :item, true, false},
          {:player, :auto, true, false},
          {:player, :direct, true, false},
          {:mob, :mob, true, false},
          {:mob, :normal, true, false}
        ] do
      state = Trap.place_state(1, @stats, group(caster_type, origin, paid_return?))
      assert state.trap.return_item_on_expiry? == expected
    end
  end

  test "harmful PvE policy is relative to the caster side" do
    assert Trap.enemy?(group(:player, :normal), {:mob, 20})
    refute Trap.enemy?(group(:player, :normal), {:player, 20})
    assert Trap.enemy?(group(:mob, :mob), {:player, 20})
    refute Trap.enemy?(group(:mob, :mob), {:mob, 20})
  end
end
