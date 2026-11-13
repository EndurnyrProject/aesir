defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GunShotsCastTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsRapidshower
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsTracking
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsTripleaction
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "Triple Action spends a coin and ammunition without a weapon" do
    caster = caster(nil, 6)
    definition = GsTripleaction.definition()

    assert {:ok, prepared} =
             Caster.Player.castend_cost(caster, GsTripleaction, {:unit, 2}, definition, 1)

    {paid, remaining} = Caster.Player.commit_primary(caster, prepared)
    paid = Caster.Player.commit(paid, remaining)
    assert SpiritSpheres.count(paid.spirit_spheres) == 0
    assert paid.inventory[1].amount == 5
    assert paid.stats.current_state.sp == 80
  end

  test "Rapid Shower spends the mode's bullet count" do
    caster = caster(13_100, 6)
    definition = GsRapidshower.definition()

    assert {:ok, prepared} =
             Caster.Player.castend_cost(caster, GsRapidshower, {:unit, 2}, definition, 1)

    {paid, remaining} = Caster.Player.commit_primary(caster, prepared)
    paid = Caster.Player.commit(paid, remaining)
    assert paid.inventory[1].amount == if(GameMode.mode() == :renewal, do: 5, else: 1)
  end

  test "missing ammunition refuses cast end without spending resources" do
    caster = caster(nil, 0)
    definition = GsTripleaction.definition()

    assert {:error, :no_ammo} =
             Caster.Player.castend_cost(caster, GsTripleaction, {:unit, 2}, definition, 1)

    assert caster.stats.current_state.sp == 100
    assert SpiritSpheres.count(caster.spirit_spheres) == 1
    assert caster.inventory == %{}
  end

  test "Tracking ignores DEX and status cast modifiers at each level" do
    definition = GsTracking.definition()
    caster = caster(13_100, 6)

    caster = %{
      caster
      | stats: %{caster.stats | base_stats: %{caster.stats.base_stats | dex: 150, int: 230}}
    }

    caster = %{caster | stats: %{caster.stats | combat_stats: %CombatStats{}}}
    :ok = UnitRegistry.register_unit(:player, 101, PlayerState, caster, self())

    :ok =
      StatusStorage.apply_status(:player, 101, :sc_suffragium, state: %{cast_time_reduction: 50})

    inputs = Caster.Player.cast_stats(caster, definition.id)
    assert inputs.dex == 150
    assert inputs.statuses.suffragium == 50

    for level <- 1..10 do
      expected =
        if GameMode.mode() == :renewal,
          do: 500 + 100 * level,
          else: 1_000 + 200 * level

      assert %{total: ^expected} = CastTime.compute(definition, level, inputs)
    end
  end

  defp caster(weapon, ammo) do
    {spheres, _} = SpiritSpheres.summon(SpiritSpheres.new(), 60_000, 5)

    inventory =
      if ammo == 0,
        do: %{},
        else: %{1 => %InventoryItem{nameid: 13_200, amount: ammo, equip: 0x008000}}

    PlayerStateFixture.build(%{
      character_id: 101,
      spirit_spheres: spheres,
      inventory: inventory,
      pending_inventory_persist: [],
      stats: %{equipment: %{right_hand: weapon}}
    })
  end
end
