defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CrusaderGuardStatusesTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Endure
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ReflectShield
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect

  setup :setup_ets_tables
  setup :verify_on_exit!

  test "Guard's block chance grows 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, then 0, 0, then 1 per level" do
    assert Enum.map(0..13, &Autoguard.block_chance/1) ==
             [0, 5, 10, 14, 18, 21, 24, 26, 28, 29, 30, 30, 30, 31]

    assert Autoguard.block_chance(48) == 66
  end

  describe "Reflect Shield" do
    @melee %{damage: 100, dmg_type: :physical, is_short: true}

    test "an inherited copy reflects skills but not normal attacks" do
      stub(SpecialEffect, :play, fn _unit, _effect, _area -> :ok end)
      copy = %StatusEntry{type: :sc_reflectshield, val1: 5, state: %{inherited: true}}

      assert :ok = ReflectShield.after_damage_taken({:player, 1}, copy, @melee, %{})

      assert {:reflect, 25} =
               ReflectShield.after_damage_taken(
                 {:player, 1},
                 copy,
                 Map.put(@melee, :skill_id, 5),
                 %{}
               )
    end

    test "a devotee out of its Crusader's range reflects nothing" do
      stub(SpecialEffect, :play, fn _unit, _effect, _area -> :ok end)
      link_id = make_ref()

      :ok =
        StatusStorage.apply_status(:player, 2, :sc_devotion,
          state: %{peer: {:player, 1}, link_id: link_id, range: 7}
        )

      :ok =
        StatusStorage.apply_status(:player, 1, :sc_devoted_by,
          state: %{links: %{2 => %{peer: {:player, 2}, link_id: link_id}}}
        )

      :ok = SpatialIndex.add_player(1, 10, 10, "prontera")
      :ok = SpatialIndex.add_player(2, 18, 10, "prontera")
      own = %StatusEntry{type: :sc_reflectshield, val1: 5, state: %{}}

      assert :ok = ReflectShield.after_damage_taken({:player, 2}, own, @melee, %{})

      :ok = SpatialIndex.update_position(2, 17, 10, "prontera")
      assert {:reflect, 25} = ReflectShield.after_damage_taken({:player, 2}, own, @melee, %{})
    end
  end

  describe "Endure" do
    defp endure(val4 \\ 0),
      do: %StatusEntry{type: :sc_endure, val1: 3, val4: val4, state: %{hits_remaining: 1}}

    test "only a connected hit from a non-player off siege ground uses a hit" do
      :ok = SpatialIndex.add_player(1, 10, 10, "prontera")
      mob_hit = %{damage: 10, attacker: {:mob, 9}}

      assert :remove = Endure.on_damage({:player, 1}, endure(), mob_hit, %{})
      assert {:ok, _} = Endure.on_damage({:player, 1}, endure(), %{mob_hit | damage: 0}, %{})

      reflected_for_nothing = Map.merge(mob_hit, %{damage: 0, proc_event: %{hit_class: :hit}})
      assert :remove = Endure.on_damage({:player, 1}, endure(), reflected_for_nothing, %{})

      missed = Map.put(mob_hit, :proc_event, %{hit_class: :miss})
      assert {:ok, _} = Endure.on_damage({:player, 1}, endure(), missed, %{})

      assert {:ok, _} =
               Endure.on_damage({:player, 1}, endure(), %{mob_hit | attacker: {:player, 3}}, %{})

      assert {:ok, _} =
               Endure.on_damage({:player, 1}, endure(), Map.delete(mob_hit, :attacker), %{})

      assert {:ok, _} = Endure.on_damage({:player, 1}, endure(1), mob_hit, %{})

      Mimic.copy(MapFlags)
      stub(MapFlags, :get, fn "prontera", flag -> flag == :gvg_castle end)
      assert {:ok, _} = Endure.on_damage({:player, 1}, endure(), mob_hit, %{})
    end

    test "grants its level as MDEF, 1 when infinite, none with val3, and survives death" do
      assert Endure.modifiers(%StatusEntry{val1: 3, val3: 0, val4: 0}, %{}) == %{mdef: 3}
      assert Endure.modifiers(%StatusEntry{val1: 3, val3: 0, val4: 1}, %{}) == %{mdef: 1}
      assert Endure.modifiers(%StatusEntry{val1: 3, val3: 1, val4: 0}, %{}) == %{}
      refute Registry.get_definition(:sc_endure).remove_on_death
    end
  end
end
