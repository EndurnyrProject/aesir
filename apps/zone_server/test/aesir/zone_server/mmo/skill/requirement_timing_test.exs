defmodule Aesir.ZoneServer.Mmo.Skill.RequirementTimingTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :set_mimic_private
  setup :setup_ets_tables
  setup :verify_on_exit!

  @gem_id 717
  @probe_id 29

  defmodule ProbeSkill do
    @moduledoc false
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    alias Aesir.ZoneServer.Unit.Inventory
    alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

    @impl true
    def cast(caster, _target, _level, _definition) do
      send(
        self(),
        {:effect_saw, caster.stats.current_state, caster.zeny,
         SpiritSpheres.count(caster.spirit_spheres), Inventory.held_amount(caster.inventory, 717),
         caster.spirit_spheres_old}
      )

      Process.get(:probe_result, {:ok, caster}) |> resolve(caster)
    end

    @impl true
    def validate(_caster, _target, _level, _definition), do: :ok

    @impl true
    def dynamic_cost(caster, _target, level, definition) do
      cost = Aesir.ZoneServer.Mmo.Skill.Cost.from_definition(caster, definition, level)
      %{cost | spheres_old: Process.get(:probe_spheres_old)}
    end

    @impl true
    def castend_requirement(_caster, _target, _level, _definition),
      do: Process.get(:probe_castend, :ok)

    @impl true
    def castend_failed(caster, _target, _level, _definition) do
      if Process.get(:probe_reacts?, false) do
        send(self(), {:castend_failed_saw, caster.stats.current_state.sp})
        {:ok, %{caster | zeny: 1}}
      else
        :none
      end
    end

    defp resolve(:deferred, caster), do: {:deferred, caster, :probe}
    defp resolve(:no_consume, caster), do: {:ok, caster, :no_consume}
    defp resolve(:skipped, caster), do: {:skipped, caster, :target_dead}
    defp resolve(other, _caster), do: other
  end

  defp definition(overrides \\ []) do
    struct(
      %Definition{
        id: @probe_id,
        name: :probe_skill,
        display_name: "Probe",
        max_level: 1,
        target_type: :self,
        damage_type: :no_damage,
        hp_cost: [10],
        sp_cost: [20],
        sphere_cost: [2],
        zeny_cost: [30],
        item_cost: [%{id: @gem_id, amount: 1}]
      },
      overrides
    )
  end

  defp stub_probe(definition) do
    stub(Catalog, :by_id, fn
      @probe_id -> {:ok, definition}
      other -> call_original(Catalog, :by_id, [other])
    end)

    stub(Catalog, :active_module_for, fn
      :probe_skill -> {:ok, ProbeSkill}
      other -> call_original(Catalog, :active_module_for, [other])
    end)
  end

  defp stub_probe_as(id, definition) do
    stub(Catalog, :by_id, fn
      ^id -> {:ok, definition}
      other -> call_original(Catalog, :by_id, [other])
    end)

    stub(Catalog, :active_module_for, fn
      :probe_skill -> {:ok, ProbeSkill}
      other -> call_original(Catalog, :active_module_for, [other])
    end)
  end

  defp learned(id),
    do: %{caster().stats | progression: %PlayerProgression{learned_skills: %{id => 1}}}

  defp spheres(count) do
    Enum.reduce(1..count//1, SpiritSpheres.new(), fn _, acc ->
      {next, _entry} = SpiritSpheres.summon(acc, 60_000, 5)
      next
    end)
  end

  defp caster(overrides \\ %{}) do
    Map.merge(
      %PlayerState{
        character_id: 1000,
        x: 10,
        y: 10,
        map_name: "prontera",
        action_state: :idle,
        movement_state: :standing,
        skill_cooldowns: %{},
        act_delay_until: 0,
        zeny: 100,
        spirit_spheres: spheres(3),
        inventory: %{0 => %InventoryItem{nameid: @gem_id, amount: 2, equip: 0}},
        pending_inventory_persist: [],
        stats: %PlayerStats{
          base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
          current_state: %CurrentState{sp: 50, hp: 100},
          derived_stats: %DerivedStats{max_sp: 200, max_hp: 100},
          progression: %PlayerProgression{learned_skills: %{@probe_id => 1}},
          equipment: %Equipment{}
        }
      },
      overrides
    )
  end

  describe "primary requirements" do
    test "the effect runs on the paid HP, SP, spheres and zeny; the item goes after it" do
      stub_probe(definition())

      assert {:ok, updated} = Interpreter.cast(caster(), @probe_id, 1, :self)

      assert_received {:effect_saw, %CurrentState{hp: 90, sp: 30}, 70, 1, 2, 0}
      assert Inventory.held_amount(updated.inventory, @gem_id) == 1
      assert updated.stats.current_state == %CurrentState{hp: 90, sp: 30}
      assert updated.zeny == 70
      assert SpiritSpheres.count(updated.spirit_spheres) == 1
    end

    test "an effect that errors leaves the cast unpaid unless the skill reacts to it" do
      stub_probe(definition())
      Process.put(:probe_result, {:error, :fizzled})

      assert {:error, :fizzled} = Interpreter.cast(caster(), @probe_id, 1, :self)

      Process.put(:probe_reacts?, true)

      assert {:castend_failed, %{zeny: 1}, :fizzled} =
               Interpreter.cast(caster(), @probe_id, 1, :self)

      assert_received {:castend_failed_saw, 50}
    end

    test "a skipped use spares the ammo the reference's early return never spends" do
      ammo_bit = EquipLocation.location_bit(:ammo)

      caster =
        caster(%{
          inventory: %{
            0 => %InventoryItem{nameid: @gem_id, amount: 2, equip: 0},
            1 => %InventoryItem{nameid: 1_751, amount: 5, equip: ammo_bit}
          }
        })

      stub_probe(definition(requires_ammo: true, cooldown: [], after_cast_delay: []))

      Process.put(:probe_result, :skipped)
      assert {:skipped, skipped, :target_dead} = Interpreter.cast(caster, @probe_id, 1, :self)
      assert skipped.inventory[1].amount == 5

      Process.delete(:probe_result)
      assert {:ok, consumed} = Interpreter.cast(caster, @probe_id, 1, :self)
      assert consumed.inventory[1].amount == 4
    end

    test "a use the reference ends without its effect keeps the requirement and spares its items" do
      stub_probe(definition(cooldown: [10_000], after_cast_delay: [1_000]))
      Process.put(:probe_result, :skipped)
      before = System.monotonic_time(:millisecond)

      assert {:skipped, caster, :target_dead} = Interpreter.cast(caster(), @probe_id, 1, :self)

      assert_received {:effect_saw, %CurrentState{hp: 90, sp: 30}, 70, 1, 2, 0}
      assert Inventory.held_amount(caster.inventory, @gem_id) == 2
      assert caster.skill_cooldowns[@probe_id] >= before + 10_000
      assert caster.act_delay_until >= before + 1_000
    end

    test "a deferred cast carries only the item left to settle" do
      stub_probe(definition())
      Process.put(:probe_result, :deferred)

      assert {:deferred, paid, %Interpreter.Deferred{cost: cost, zeny: 0} = deferred} =
               Interpreter.cast(caster(), @probe_id, 1, :self)

      assert paid.stats.current_state == %CurrentState{hp: 90, sp: 30}
      assert paid.zeny == 70
      assert %Cost{hp: 0, sp: 0, spheres: 0} = cost

      assert {:ok, settled} = Interpreter.settle_deferred(paid, deferred)
      assert settled.stats.current_state == %CurrentState{hp: 90, sp: 30}
      assert settled.zeny == 70
      assert SpiritSpheres.count(settled.spirit_spheres) == 1
      assert Inventory.held_amount(settled.inventory, @gem_id) == 1
    end
  end

  describe "the source's type-1 exceptions" do
    test "Item Appraisal pays its SP after the effect, and not at all when it spares its requirement" do
      stub_probe_as(
        40,
        definition(
          id: 40,
          sp_cost: [10],
          hp_cost: [],
          sphere_cost: [],
          zeny_cost: [],
          item_cost: []
        )
      )

      appraiser = caster(%{stats: learned(40)})

      assert {:ok, appraised} = Interpreter.cast(appraiser, 40, 1, :self)
      assert_received {:effect_saw, %CurrentState{sp: 50}, _zeny, _spheres, _gems, _old}
      assert appraised.stats.current_state.sp == 40

      Process.put(:probe_result, :no_consume)
      assert {:ok, unpaid} = Interpreter.cast(appraiser, 40, 1, :self)
      assert unpaid.stats.current_state.sp == 50
    end

    test "Ki Translation pays its SP first and leaves the sphere to the transfer" do
      stub_probe_as(
        1_015,
        definition(
          id: 1_015,
          sp_cost: [40],
          sphere_cost: [1],
          hp_cost: [],
          zeny_cost: [],
          item_cost: []
        )
      )

      Process.put(:probe_result, :deferred)

      assert {:deferred, paid, %Interpreter.Deferred{cost: %Cost{sp: 0, spheres: 1}} = deferred} =
               Interpreter.cast(caster(%{stats: learned(1_015)}), 1_015, 1, :self)

      assert_received {:effect_saw, %CurrentState{sp: 10}, _zeny, 3, _gems, _old}
      assert SpiritSpheres.count(paid.spirit_spheres) == 3

      assert {:ok, settled} = Interpreter.settle_deferred(paid, deferred)
      assert settled.stats.current_state.sp == 10
      assert SpiritSpheres.count(settled.spirit_spheres) == 2
    end
  end

  describe "recorded sphere count" do
    test "the cast-begin check records it and the cast end keeps it" do
      stub_probe(definition(sphere_cost: [], hp_cost: [], zeny_cost: [], item_cost: []))
      Process.put(:probe_spheres_old, 3)

      assert {:ok, updated} = Interpreter.cast(caster(), @probe_id, 1, :self)

      assert_received {:effect_saw, _current, _zeny, 3, _gems, 3}
      assert updated.spirit_spheres_old == 3
    end

    test "a cost recording nothing keeps the previous count" do
      stub_probe(definition(sphere_cost: [], hp_cost: [], zeny_cost: [], item_cost: []))

      assert {:ok, updated} =
               Interpreter.cast(caster(%{spirit_spheres_old: 4}), @probe_id, 1, :self)

      assert_received {:effect_saw, _current, _zeny, _spheres, _gems, 4}
      assert updated.spirit_spheres_old == 4
    end
  end

  describe "cast-end failure reaction" do
    test "a refused cast end hands the skill's failure state to the owner" do
      stub_probe(definition())
      Process.put(:probe_castend, {:error, :refused})
      Process.put(:probe_reacts?, true)

      assert {:castend_failed, failed, :refused} =
               Interpreter.cast(caster(), @probe_id, 1, :self)

      assert_received {:castend_failed_saw, 50}
      refute_received {:effect_saw, _, _, _, _, _}
      assert failed.zeny == 1
    end
  end

  describe "status autocast" do
    test "charges its SP before the effect and keeps it, with the delay, when the effect fails" do
      stub_probe(definition(sp_cost: [30], after_cast_delay: [1_000]))
      Process.put(:probe_result, {:error, :fizzled})
      before = System.monotonic_time(:millisecond)

      assert {:error, :fizzled, charged} = Interpreter.auto_cast(caster(), @probe_id, 1, :self)

      assert_received {:effect_saw, %CurrentState{sp: 30}, _zeny, _spheres, _gems, _old}
      assert charged.stats.current_state.sp == 30
      assert charged.act_delay_until >= before + 1_000
    end
  end
end
