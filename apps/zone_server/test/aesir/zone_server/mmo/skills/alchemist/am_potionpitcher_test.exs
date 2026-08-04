defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcherTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    {:ok, definition} = Catalog.by_id(231)
    {:ok, definition: definition}
  end

  defp caster(item_id, opts \\ []) do
    %PlayerState{
      character_id: 10,
      party_id: Keyword.get(opts, :party_id, 0),
      guild_id: Keyword.get(opts, :guild_id, 0),
      inventory: %{0 => %InventoryItem{nameid: item_id, amount: 2, equip: 0}},
      pending_inventory_persist: [],
      stats: %{
        progression: %{learned_skills: %{227 => Keyword.get(opts, :learning_potion, 0)}}
      }
    }
  end

  defp target(opts) do
    %PlayerState{
      character_id: Keyword.fetch!(opts, :id),
      party_id: Keyword.get(opts, :party_id, 0),
      guild_id: Keyword.get(opts, :guild_id, 0),
      action_state: Keyword.get(opts, :action_state, :idle),
      stats: %{current_state: %{hp: Keyword.get(opts, :hp, 100)}}
    }
  end

  defp homunculus(owner_id, gid, opts \\ []) do
    %HomunculusState{
      id: gid + 1,
      owner_character_id: owner_id,
      class_id: 6_001,
      name: "Hildr",
      lifecycle: :active,
      action_state: Keyword.get(opts, :action_state, :idle),
      hp: Keyword.get(opts, :hp, 100),
      max_hp: 100,
      world_gid: gid,
      map_name: "test",
      x: 10,
      y: 10
    }
  end

  test "metadata is catalogued", %{definition: definition} do
    assert definition.name == :am_potionpitcher
    assert definition.max_level == 5
    assert definition.target_type == :target_ally
    assert definition.range == 9
    assert definition.sp_cost == [1, 1, 1, 1, 1]
    assert definition.after_cast_delay == [500, 500, 500, 500, 500]
    assert definition.cast_time == []
  end

  test "level selects one potion and stages one deferred delivery", %{definition: definition} do
    expected = [
      {1, 501, :hp, 45, 65},
      {2, 502, :hp, 105, 145},
      {3, 503, :hp, 175, 235},
      {4, 504, :hp, 325, 405},
      {5, 505, :sp, 40, 60}
    ]

    for {level, item_id, resource, minimum, maximum} <- expected do
      state = caster(item_id)

      assert {:deferred, updated, {:potion_delivery, {:player, 10}, {:potion, ^resource, amount}}} =
               AmPotionpitcher.cast(state, :self, level, definition)

      assert ItemContainer.held_amount(updated.inventory, item_id) == 1
      assert length(updated.pending_inventory_persist) == 1

      assert amount in AmPotionpitcher.scale_caster_bonus(minimum, level, 0)..AmPotionpitcher.scale_caster_bonus(
               maximum,
               level,
               0
             )
    end
  end

  test "caster multiplier contains Pitcher and Learning Potion terms" do
    assert AmPotionpitcher.scale_caster_bonus(100, 3, 4) == 150
    assert AmPotionpitcher.scale_caster_bonus(45, 1, 0) == 49
  end

  test "Blue Potion stages SP rather than HP", %{definition: definition} do
    assert {:deferred, _updated, {:potion_delivery, {:player, 10}, {:potion, :sp, amount}}} =
             AmPotionpitcher.cast(caster(505, learning_potion: 10), :self, 5, definition)

    assert amount in 80..120
  end

  test "validate accepts self", %{definition: definition} do
    assert :ok = AmPotionpitcher.validate(caster(501), :self, 1, definition)
    assert :ok = AmPotionpitcher.validate(caster(501), {:unit, 10}, 1, definition)
  end

  test "validate accepts a live party member", %{definition: definition} do
    member = target(id: 20, party_id: 7)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, member, self()}} end)

    assert :ok = AmPotionpitcher.validate(caster(501, party_id: 7), {:unit, 20}, 1, definition)
  end

  test "validate accepts a live guild member", %{definition: definition} do
    member = target(id: 20, guild_id: 7)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, member, self()}} end)

    assert :ok = AmPotionpitcher.validate(caster(501, guild_id: 7), {:unit, 20}, 1, definition)
  end

  test "validate accepts only the exact owner's live Homunculus", %{definition: definition} do
    owned = homunculus(10, 30)
    foreign = homunculus(11, 31)

    stub(UnitRegistry, :get_unit, fn
      :homunculus, 30 -> {:ok, {HomunculusState, owned, self()}}
      :homunculus, 31 -> {:ok, {HomunculusState, foreign, self()}}
    end)

    assert :ok =
             AmPotionpitcher.validate(caster(501), {:unit, {:homunculus, 30}}, 1, definition)

    assert {:error, :invalid_target} =
             AmPotionpitcher.validate(caster(501), {:unit, {:homunculus, 31}}, 1, definition)
  end

  test "stranger is rejected without consumption", %{definition: definition} do
    stranger = target(id: 20)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, stranger, self()}} end)
    state = caster(501, party_id: 7)

    assert {:error, :invalid_target} = AmPotionpitcher.cast(state, {:unit, 20}, 1, definition)
    assert ItemContainer.held_amount(state.inventory, 501) == 2
  end

  test "dead ally is rejected without consumption", %{definition: definition} do
    dead = target(id: 20, party_id: 7, action_state: :dead, hp: 0)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, dead, self()}} end)
    state = caster(501, party_id: 7)

    assert {:error, :invalid_target} = AmPotionpitcher.cast(state, {:unit, 20}, 1, definition)
    assert ItemContainer.held_amount(state.inventory, 501) == 2
  end

  test "missing selected potion returns an error without staging another potion", %{
    definition: definition
  } do
    state = caster(501)

    assert {:error, :missing_potion} = AmPotionpitcher.cast(state, :self, 2, definition)
    assert ItemContainer.held_amount(state.inventory, 501) == 2
    assert state.pending_inventory_persist == []
  end
end
