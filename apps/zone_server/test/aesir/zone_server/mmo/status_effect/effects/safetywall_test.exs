defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SafetywallTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Safetywall
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :setup_ets_tables

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    :ok
  end

  @target {:player, 1000}

  defp instance(group_id) do
    %StatusEntry{type: :sc_safetywall, val2: group_id, state: %{group_id: group_id}}
  end

  defp place_wall(group_id, budget) do
    Storage.insert(%Group{
      group_id: group_id,
      skill_id: 12,
      skill_name: :mg_safetywall,
      level: 5,
      caster_id: 2000,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: budget
    })
  end

  describe "metadata" do
    test "is a buff" do
      assert :sc_safetywall = Safetywall.id()
      assert %{properties: [:buff]} = Safetywall.metadata()
    end
  end

  describe "on_apply/3" do
    test "keeps only the owning group_id as the unit<->status linkage" do
      base = %StatusEntry{type: :sc_safetywall, val2: 42, state: %{}}

      assert {:ok, %StatusEntry{state: %{group_id: 42}}} = Safetywall.on_apply(@target, base, %{})
    end
  end

  describe "absorb_damage/4 - melee physical" do
    test "blocks fully, spending a hit and the damage from the wall's shared budget" do
      place_wall(42, %{hits_remaining: 6, shield_hp: 9_500})
      entry = instance(42)
      hit = %{damage: 1_000, is_short: true, dmg_type: :physical, element: :neutral}

      assert {:ok, 0, ^entry} = Safetywall.absorb_damage(@target, entry, hit, %{})

      assert %Group{state: %{hits_remaining: 5, shield_hp: 8_500}} = Storage.get(42)
    end

    test "removes and tears down the wall when the hit budget is exhausted" do
      place_wall(42, %{hits_remaining: 1, shield_hp: 9_500})
      entry = instance(42)
      hit = %{damage: 100, is_short: true, dmg_type: :physical, element: :neutral}

      assert {:remove, 0} = Safetywall.absorb_damage(@target, entry, hit, %{})
      assert nil == Storage.get(42)
    end

    test "removes and tears down the wall when the shield pool is exhausted" do
      place_wall(42, %{hits_remaining: 6, shield_hp: 80})
      entry = instance(42)
      hit = %{damage: 100, is_short: true, dmg_type: :physical, element: :neutral}

      assert {:remove, 0} = Safetywall.absorb_damage(@target, entry, hit, %{})
      assert nil == Storage.get(42)
    end

    test "ends the status when the wall is already gone" do
      entry = instance(42)
      hit = %{damage: 100, is_short: true, dmg_type: :physical, element: :neutral}

      assert :remove = Safetywall.absorb_damage(@target, entry, hit, %{})
    end

    test "does not spend the wall budget on a zero-damage physical hit" do
      place_wall(42, %{hits_remaining: 6, shield_hp: 9_500})
      entry = instance(42)
      hit = %{damage: 0, is_short: true, dmg_type: :physical, element: :neutral}

      assert {:ok, 0, ^entry} = Safetywall.absorb_damage(@target, entry, hit, %{})
      assert %Group{state: %{hits_remaining: 6, shield_hp: 9_500}} = Storage.get(42)
    end
  end

  describe "absorb_damage/4 - pass-through" do
    test "magic hits pass through unmodified" do
      entry = instance(42)
      hit = %{damage: 700, is_short: true, dmg_type: :magic, element: :fire}

      assert {:ok, 700, ^entry} = Safetywall.absorb_damage(@target, entry, hit, %{})
    end

    test "ranged physical hits pass through unmodified" do
      entry = instance(42)
      hit = %{damage: 500, is_short: false, dmg_type: :physical, element: :neutral}

      assert {:ok, 500, ^entry} = Safetywall.absorb_damage(@target, entry, hit, %{})
    end
  end
end
