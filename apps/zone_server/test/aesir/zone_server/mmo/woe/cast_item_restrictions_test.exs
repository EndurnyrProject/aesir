defmodule Aesir.ZoneServer.Mmo.Woe.CastItemRestrictionsTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemUseResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @castle "aldeg_cas01"
  @shared_skill_bans [26, 27, 87, 150, 219]
  @greed 1013
  @greed_scroll 14_529
  @anodyne 605

  defmodule ItemCastSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(caster, :self, 1, _definition) do
      send(self(), :item_cast_ran)
      {:ok, caster}
    end

    @impl true
    def validate(_caster, :self, 1, _definition), do: :ok
  end

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets

  setup do
    Mimic.copy(Catalog)
    Mimic.copy(Items)
    Mimic.copy(InventoryOps)

    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusManager, :recalculate_after_status_change, fn state -> state end)

    :ok
  end

  test "ordinary cast bans apply at begin and completion on inactive castle ground" do
    caster = player(@castle)

    for skill_id <- @shared_skill_bans do
      assert {:error, :skill_not_allowed} =
               Interpreter.begin_cast(caster, skill_id, 1, :self)

      assert {:error, :skill_not_allowed} =
               Interpreter.complete_cast(caster, skill_id, 1, :self)
    end
  end

  test "Greed ordinary-cast restriction is pre-renewal only in both phases" do
    expected = if GameMode.mode() == :pre_renewal, do: {:error, :skill_not_allowed}, else: :ok
    caster = player(@castle)

    for phase <- [:begin, :completion] do
      assert Caster.Player.castable_state(caster, @greed, phase) == expected
    end
  end

  test "mode-restricted items run no effect and consume nothing on inactive castle ground" do
    denied_ids =
      if GameMode.mode() == :renewal,
        do: [@greed_scroll, @anodyne],
        else: [@greed_scroll]

    definitions = Enum.map(denied_ids, &item_definition/1)
    ScriptCompiler.compile_all!(definitions)

    stub(Items, :by_id, fn id -> {:ok, Enum.find(definitions, &(&1.id == id))} end)
    reject(&InventoryOps.remove/4)

    for item_id <- denied_ids do
      state = item_state(item_id, @castle)

      assert {:noreply, ^state} = ItemHandler.handle_use_item(2, state)
      assert state.game_state.stats.current_state.hp == 100

      assert_received {:send, :gameplay, {:item_use_result, %ItemUseResult{ok: false, reason: 3}}}

      refute_received {:send, :gameplay, {:item_removed, _}}
    end
  end

  test "a nonrestricted item still executes and consumes on castle ground" do
    definition = item_definition(501)
    ScriptCompiler.compile_all!([definition])
    stub(Items, :by_id, fn 501 -> {:ok, definition} end)

    expect(InventoryOps, :remove, fn 1000, inventory, 0, 1 ->
      {:ok, %{0 => %{inventory[0] | amount: 1}}, {:reduced, 0, 1}}
    end)

    state = item_state(501, @castle)
    assert {:noreply, updated} = ItemHandler.handle_use_item(2, state)
    assert updated.game_state.stats.current_state.hp == 150
    assert updated.game_state.inventory[0].amount == 1
    assert_received {:send, :gameplay, {:item_removed, %ItemRemoved{amount: 1}}}
    assert_received {:send, :gameplay, {:item_use_result, %ItemUseResult{ok: true}}}
  end

  test "item casts do not inherit the ordinary skill ban" do
    definition = %Definition{
      id: 26,
      name: :item_cast_fixture,
      display_name: "Item Cast Fixture",
      max_level: 1,
      target_type: :self
    }

    stub(Catalog, :by_id, fn 26 -> {:ok, definition} end)
    stub(Catalog, :active_module_for, fn :item_cast_fixture -> {:ok, ItemCastSkill} end)

    assert {:ok, _updated} = Interpreter.item_cast(player(@castle), 26, 1, :self)
    assert_received :item_cast_ran
  end

  defp setup_ets(context) do
    Aesir.TestEtsSetup.setup_ets_tables(context)
    MapFlags.reload()
  end

  defp item_state(item_id, map_name) do
    inventory = %{0 => %InventoryItem{id: 1, nameid: item_id, amount: 2}}
    %{connection_pid: self(), game_state: %{player(map_name) | inventory: inventory}}
  end

  defp item_definition(id) do
    %ItemDefinition{
      id: id,
      aegis_name: "Item_#{id}",
      name: "Item #{id}",
      type: :healing,
      on_use: "heal(ctx, hp: 50)"
    }
  end

  defp player(map_name) do
    %PlayerState{
      character_id: 1000,
      account_id: 2000,
      sex: "M",
      x: 50,
      y: 50,
      map_name: map_name,
      action_state: :idle,
      movement_state: :standing,
      act_delay_until: 0,
      skill_cooldowns: %{},
      stats: %Stats{
        base_stats: %BaseStats{vit: 0, int: 0},
        current_state: %CurrentState{hp: 100, sp: 100},
        derived_stats: %DerivedStats{max_hp: 500, max_sp: 200, aspd: 150},
        progression: %PlayerProgression{learned_skills: %{@greed => 1}},
        equipment: %Equipment{},
        modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}, passive: %{}}
      },
      inventory: %{}
    }
  end
end
