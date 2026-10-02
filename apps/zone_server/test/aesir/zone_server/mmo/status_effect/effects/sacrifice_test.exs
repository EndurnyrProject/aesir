defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SacrificeTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sacrifice
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @holder_id 43_001
  @context %{target: %{max_hp: 10_000}}

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Helpers)
    Mimic.copy(UnitRegistry)
    stub(UnitRegistry, :get_unit_info, fn :player, @holder_id -> {:ok, %{stats: %{}}} end)
    :ok
  end

  test "is a permanent, non-persisted player buff with the attack replacement capability" do
    definition = Registry.get_definition(:sc_sacrifice)

    assert definition.permanent
    assert definition.no_save
    assert :buff in definition.properties
    assert MapSet.member?(Registry.statuses_implementing(:attack_replacement), :sc_sacrifice)
  end

  test "on apply seeds five remaining swings" do
    assert {:ok, %StatusEntry{state: %{remaining: 5}}} =
             Sacrifice.on_apply({:player, @holder_id}, %StatusEntry{}, %{})
  end

  test "each swing becomes a max-HP strike that ignores DEF, FLEE, size and status ATK" do
    hold(3, 5)
    expect(Helpers, :deal_damage, fn {:player, @holder_id}, 900 -> :ok end)

    assert {:skill_attack, opts} =
             Sacrifice.attack_replacement({:player, @holder_id}, entry(), @context)

    assert Enum.sort(opts) ==
             Enum.sort(
               skill_id: 368,
               skill_level: 3,
               base_damage: 900,
               skill_ratio: 120,
               ignore_defense: true,
               ignore_flee: true,
               ignore_size: true,
               skip_crit: true,
               skip_status_atk: true
             )

    assert %StatusEntry{state: %{remaining: 4}} =
             StatusStorage.get_status(:player, @holder_id, :sc_sacrifice)
  end

  test "the fifth swing ends the status" do
    hold(1, 1)
    stub(Helpers, :deal_damage, fn _target, _amount -> :ok end)

    assert {:skill_attack, _opts} =
             Sacrifice.attack_replacement({:player, @holder_id}, entry(), @context)

    refute StatusStorage.has_status?(:player, @holder_id, :sc_sacrifice)
  end

  defp hold(level, remaining) do
    :ok =
      StatusStorage.apply_status(:player, @holder_id, :sc_sacrifice,
        val1: level,
        state: %{remaining: remaining}
      )
  end

  defp entry, do: StatusStorage.get_status(:player, @holder_id, :sc_sacrifice)
end
