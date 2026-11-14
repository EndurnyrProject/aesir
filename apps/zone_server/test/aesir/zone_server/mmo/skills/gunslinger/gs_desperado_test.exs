defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDesperadoTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.GroupLifecycle
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDesperado
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsRapidshower
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private

  describe "desperado_cell_chance_test" do
    test "the cross falls 36, 36, 24, 12 from the centre" do
      for {dx, dy} <- [{0, 0}, {1, 0}, {0, 1}, {1, 1}],
          do: assert(GsDesperado.cell_chance(dx, dy) == 36)

      for {dx, dy} <- [{2, 0}, {2, 1}, {0, 2}, {1, 2}],
          do: assert(GsDesperado.cell_chance(dx, dy) == 24)

      for {dx, dy} <- [{3, 0}, {3, 1}, {1, 3}], do: assert(GsDesperado.cell_chance(dx, dy) == 12)
    end

    test "the corner region is 12, 8, 4 and never below 1" do
      assert GsDesperado.cell_chance(2, 2) == 12
      assert GsDesperado.cell_chance(3, 2) == 8
      assert GsDesperado.cell_chance(2, 3) == 8
      assert GsDesperado.cell_chance(3, 3) == 4
      assert GsDesperado.cell_chance(4, 4) == 1
    end
  end

  describe "desperado_ammo_settled_once_test" do
    test "expiry, trigger and caster loss each settle ten bullets once" do
      stub(UnitRegistry, :get_player_pid, fn 101 -> {:ok, self()} end)

      deletions = [
        {1, &GroupLifecycle.cleanup/1},
        {2, &GroupLifecycle.cleanup(&1, GsDesperado)},
        {3, &GroupLifecycle.cleanup_with_reason(&1, :SKILL_UNIT_DESPAWN_REASON_CANCELED)}
      ]

      for {id, delete} <- deletions do
        group = group(id)
        :ok = Storage.insert(group)

        delete.(group)
        assert_received {:"$gen_cast", {:skill, {:settle_deferred_ammo, 10}}}

        delete.(group)
        refute_received {:"$gen_cast", {:skill, {:settle_deferred_ammo, _}}}
      end
    end
  end

  describe "desperado_no_ammo_test" do
    test "fewer than ten bullets refuse the cast end with nothing spent" do
      caster = caster(9)

      assert {:error, :no_ammo} =
               Caster.Player.castend_cost(caster, GsDesperado, :self, GsDesperado.definition(), 1)
    end

    test "ten bullets pass the cast end, SP is spent and the bullets wait for the group" do
      caster = caster(10)
      definition = GsDesperado.definition()

      assert {:ok, prepared} =
               Caster.Player.castend_cost(caster, GsDesperado, :self, definition, 1)

      {paid, remaining} = Caster.Player.commit_primary(caster, prepared)
      paid = Caster.Player.commit(paid, remaining)

      assert paid.inventory[1].amount == 10
      assert paid.stats.current_state.sp == caster.stats.current_state.sp - 32
    end
  end

  describe "desperado_equip_lock_test" do
    test "equipment is held for 1000 ms after the cast and free after" do
      until = Definition.equip_lock_until(GsDesperado.definition(), 1, 5_000)

      assert 5_999 < until
      refute 6_000 < until
      assert Definition.equip_lock_until(GsRapidshower.definition(), 1, 5_000) == nil
    end
  end

  describe "desperado_fallen_angel_test" do
    test "Fallen Angel doubles the ratio" do
      stub(StatusStorage, :has_status?, fn :player, 101, :sc_fallen_angel -> true end)
      assert GsDesperado.skill_ratio(:player, 101, 1) == 200
      assert GsDesperado.skill_ratio(:player, 101, 10) == 1_100
    end

    test "without Fallen Angel the base ratio applies" do
      stub(StatusStorage, :has_status?, fn :player, 101, :sc_fallen_angel -> false end)
      assert GsDesperado.skill_ratio(:player, 101, 1) == 100
      assert GsDesperado.skill_ratio(:player, 101, 10) == 550
    end
  end

  defp group(id) do
    %Group{
      group_id: id,
      skill_id: 516,
      skill_name: :gs_desperado,
      level: 1,
      caster_id: 101,
      caster_type: :player,
      map_name: "prontera",
      center: {50, 50},
      origin: {50, 50},
      cells: [],
      created_at: 0,
      next_tick_at: 100,
      expires_at: 1_000,
      interval: 100,
      unit_range: 0,
      state: %{deferred_ammo: %{owner_type: :player, owner_id: 101, qty: 10}}
    }
  end

  defp caster(ammo) do
    PlayerStateFixture.build(%{
      character_id: 101,
      inventory: %{1 => %InventoryItem{nameid: 13_200, amount: ammo, equip: 0x008000}},
      pending_inventory_persist: [],
      stats: %{equipment: %{right_hand: 13_100}}
    })
  end
end
