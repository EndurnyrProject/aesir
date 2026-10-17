defmodule Aesir.ZoneServer.Mmo.Combat.EndureTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.Endure
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    stub(MapFlags, :get, fn map, flag -> map == "prtg_cas01" and flag == :gvg_castle end)
    :ok
  end

  defp player(map_name, equipment \\ %{}, status_effects \\ %{}) do
    stats = %Stats{}
    modifiers = %{stats.modifiers | equipment: equipment, status_effects: status_effects}
    %PlayerState{character_id: 1, map_name: map_name, stats: %{stats | modifiers: modifiers}}
  end

  defp mob(modes),
    do: struct(MobState, instance_id: 7, mob_data: struct(MobDefinition, modes: modes))

  describe "endure?/5" do
    test "nothing endures by default" do
      refute Endure.endure?(:player, 1, player("prontera"), false, 1_000)
      refute Endure.endure?(:mob, 7, mob([]), false, 1_000)
    end

    test "the unit's own endure time holds until it passes" do
      Endure.put_tick(:mob, 7, 2_000, 1_000)

      assert Endure.endure?(:mob, 7, mob([]), true, 2_999)
      refute Endure.endure?(:mob, 7, mob([]), true, 3_000)
    end

    test "a later endure time replaces an earlier one, even a shorter one" do
      Endure.put_tick(:mob, 7, 2_000, 1_000)
      Endure.put_tick(:mob, 7, 200, 1_100)

      refute Endure.endure?(:mob, 7, mob([]), true, 1_300)
    end

    test "holding the Endure status endures" do
      StatusStorage.apply_status(:player, 1, :sc_endure, val1: 1)

      assert Endure.endure?(:player, 1, player("prontera"), true, 1_000)
    end

    test "a player's no-walk-delay bonus endures, from equipment or a status" do
      assert Endure.endure?(:player, 1, player("prontera", %{no_walk_delay: 1}), true, 0)
      assert Endure.endure?(:player, 1, player("prontera", %{}, %{no_walk_delay: true}), true, 0)
    end

    test "the no-walk-delay bonus does nothing where Endure is not allowed" do
      refute Endure.endure?(:player, 1, player("prtg_cas01", %{no_walk_delay: 1}), false, 0)
    end

    @tag game_mode: :renewal
    test "a renewal boss endures only in the unshown form" do
      assert Endure.endure?(
               :mob,
               7,
               mob([:detector, :status_immune, :knockback_immune]),
               false,
               0
             )

      refute Endure.endure?(:mob, 7, mob([:detector, :status_immune, :knockback_immune]), true, 0)
    end

    @tag game_mode: :pre_renewal
    test "a classic boss does not endure" do
      refute Endure.endure?(
               :mob,
               7,
               mob([:detector, :status_immune, :knockback_immune]),
               false,
               0
             )
    end
  end

  describe "shown?/2" do
    test "reads a registered player's bonus" do
      state = player("prontera", %{no_walk_delay: 1})
      stub(UnitRegistry, :get_unit, fn :player, 1 -> {:ok, {PlayerState, state, self()}} end)

      assert Endure.shown?(:player, 1)
    end

    test "a unit type without endure never shows it" do
      reject(&UnitRegistry.get_unit/2)

      refute Endure.shown?(:skill_unit, 1)
      refute Endure.shown?(nil, 1)
    end
  end
end
