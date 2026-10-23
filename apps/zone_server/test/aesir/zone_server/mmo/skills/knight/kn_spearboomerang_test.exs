defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearboomerangTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearboomerang
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :set_mimic_private
  setup :verify_on_exit!

  @caster_id 1_000
  @target_id 2_000
  @map "prontera"
  @spear_id 1_401

  defp definition do
    {:ok, definition} = Catalog.by_name(:kn_spearboomerang)
    definition
  end

  describe "cast/4" do
    defp caster, do: %{character_id: @caster_id}

    test "skill_ratio scales as (100 + 50 * level)% at every level" do
      caster = caster()

      for level <- 1..5 do
        expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
          assert opts[:skill_id] == 59
          assert opts[:skill_level] == level
          assert opts[:skill_ratio] == 100 + 50 * level
          assert opts[:skip_crit] == true
          assert opts[:skip_range] == true
          :ok
        end)

        assert {:ok, ^caster} =
                 KnSpearboomerang.cast(caster, {:unit, @target_id}, level, definition())
      end
    end

    test "cast/4 propagates an attack error" do
      caster = caster()

      stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
        {:error, :dead_target}
      end)

      assert {:error, :dead_target} =
               KnSpearboomerang.cast(caster, {:unit, @target_id}, 3, definition())
    end
  end

  describe "the engine weapon check (spear)" do
    test "a spear-wielding player passes regardless of target distance or level" do
      caster = spear_caster(x: 0, y: 0)
      reject(&Combat.resolve_target_position/1)

      assert :ok = PlayerCaster.check_weapon(caster, definition())
    end

    test "a bare-handed player is rejected" do
      caster = unarmed_caster(x: 0, y: 0)
      reject(&Combat.resolve_target_position/1)

      assert {:error, :wrong_weapon} =
               PlayerCaster.check_weapon(caster, definition())
    end
  end

  defp spear_caster(x: x, y: y) do
    caster = unarmed_caster(x: x, y: y)
    item = %InventoryItem{nameid: @spear_id, amount: 1, equip: 0, identify: 1}

    assert {:ok, inventory, {:equipped, 0, 2, []}} =
             Inventory.equip(%{0 => item}, 0, 2, %{
               job_id: caster.stats.progression.job_id,
               base_level: caster.stats.progression.base_level,
               sex: "M"
             })

    stats = %{caster.stats | equipment: Stats.equipment_from_inventory(Map.values(inventory))}
    %{caster | inventory: inventory, stats: stats}
  end

  defp unarmed_caster(x: x, y: y) do
    player(x: x, y: y, inventory: [])
  end

  defp player(x: x, y: y, inventory: inventory) do
    base =
      PlayerState.new(%Character{
        id: @caster_id,
        account_id: @caster_id,
        name: "Knight",
        last_map: @map,
        last_x: x,
        last_y: y,
        sex: "M",
        str: 40,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 70,
        job_level: 40,
        class: 7
      })

    stats = %{base.stats | equipment: Stats.equipment_from_inventory(inventory)}
    %{base | stats: stats}
  end
end
