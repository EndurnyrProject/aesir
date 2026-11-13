defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsCrackerCostTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsCracker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  setup :setup_ets_tables
  setup :set_mimic_private

  test "resisted stun still spends SP, one coin and one bullet" do
    {spheres, _} = SpiritSpheres.summon(SpiritSpheres.new(), 60_000, 5)

    caster =
      PlayerStateFixture.build(%{
        character_id: 101,
        x: 1,
        y: 1,
        spirit_spheres: spheres,
        inventory: %{1 => %InventoryItem{nameid: 13_200, amount: 6, equip: 0x008000}},
        pending_inventory_persist: [],
        stats: %{equipment: %{right_hand: nil}}
      })

    definition = GsCracker.definition()

    assert {:ok, prepared} =
             Caster.Player.castend_cost(caster, GsCracker, {:unit, 2}, definition, 1)

    {paid, remaining} = Caster.Player.commit_primary(caster, prepared)
    stub(TargetResolver, :resolve_target_position, fn 2 -> {:ok, :mob, {2, 1, "map"}} end)
    stub(StatusInterpreter, :apply_status, fn :mob, 2, :sc_stun, _ -> {:error, :resisted} end)
    assert {:ok, paid} = GsCracker.cast(paid, {:unit, 2}, 1, definition)
    paid = Caster.Player.commit(paid, remaining)
    assert paid.stats.current_state.sp == 90
    assert SpiritSpheres.count(paid.spirit_spheres) == 0
    assert paid.inventory[1].amount == 5
  end
end
