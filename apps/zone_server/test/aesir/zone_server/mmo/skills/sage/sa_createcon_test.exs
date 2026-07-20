defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaCreateconTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaCreatecon
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  # Only the DB write-through is stubbed out; the pure inventory core still runs,
  # so stacking, slot allocation and the change descriptor are the real thing.
  setup do
    stub(InventoryOps, :add, fn _char_id, inventory, _stats, item_def, amount ->
      {:ok, new_inventory, change} = Inventory.add(inventory, item_def, amount)
      {:ok, new_inventory, change}
    end)

    :ok
  end

  @blank_scroll 7433
  @red_blood 990
  @crystal_blue 991
  @wind_of_verdure 992
  @green_live 993

  @fire_converter 12_114
  @water_converter 12_115
  @earth_converter 12_116
  @wind_converter 12_117

  defp stack(nameid, amount), do: %InventoryItem{nameid: nameid, amount: amount, equip: 0}

  defp caster(stacks) do
    inventory =
      stacks
      |> Enum.with_index()
      |> Map.new(fn {{nameid, amount}, index} -> {index, stack(nameid, amount)} end)

    %PlayerState{
      character_id: 1,
      inventory: inventory,
      stats: %{},
      pending_inventory_persist: [],
      pending_inventory_notify: []
    }
  end

  defp cast(stacks) do
    {:ok, definition} = Catalog.by_id(1007)
    SaCreatecon.cast(caster(stacks), :self, 1, definition)
  end

  defp full_caster_cast do
    cast([
      {@blank_scroll, 4},
      {@red_blood, 1},
      {@crystal_blue, 1},
      {@green_live, 1},
      {@wind_of_verdure, 1}
    ])
  end

  describe "metadata" do
    test "the catalog resolves id 1007 with the renewal skill_db values" do
      assert {:ok, SaCreatecon} = Catalog.active_module_for(:sa_createcon)
      assert {:ok, definition} = Catalog.by_id(1007)

      assert definition.name == :sa_createcon
      assert definition.max_level == 1
      assert definition.target_type == :self
      assert definition.damage_type == :no_damage
      assert definition.sp_cost == [30]
    end

    test "publishes the menu capability so an accepted reply routes back here" do
      assert {:ok, SaCreatecon} = Catalog.menu_module_for(:sa_createcon)
    end

    # Instant: skill_db gives SA_CREATECON no CastTime or FixedCastTime.
    test "has no cast time" do
      {:ok, definition} = Catalog.by_id(1007)

      assert definition.cast_time == []
      assert definition.fixed_cast_time == []
    end
  end

  describe "cast/4" do
    test "offers only the converters whose materials the caster holds" do
      assert {:ok, staged} = cast([{@blank_scroll, 2}, {@red_blood, 1}, {@wind_of_verdure, 1}])

      assert staged.pending_menu_offer == %{
               skill_id: 1007,
               kind: :ITEMS,
               entry_ids: [@fire_converter, @wind_converter],
               level: 1
             }
    end

    test "offers every converter to a caster holding all four materials" do
      assert {:ok, staged} = full_caster_cast()

      assert staged.pending_menu_offer.entry_ids == [
               @fire_converter,
               @water_converter,
               @earth_converter,
               @wind_converter
             ]
    end

    # A converter needs both halves of its recipe: the scroll alone brews nothing,
    # and neither does the elemental material alone.
    test "does not offer a converter when only one half of the recipe is held" do
      assert {:error, :no_materials} = cast([{@blank_scroll, 10}])
      assert {:error, :no_materials} = cast([{@red_blood, 10}, {@crystal_blue, 10}])
    end

    # Failing here means the interpreter charges no SP: it only consumes after the
    # behaviour runs.
    test "fails the cast when the caster holds no complete recipe" do
      assert {:error, :no_materials} = cast([])
    end
  end

  describe "on_menu_reply/3" do
    test "consumes both materials and grants 1 converter" do
      state = caster([{@blank_scroll, 1}, {@red_blood, 1}])

      assert {:ok, brewed} = SaCreatecon.on_menu_reply(state, @fire_converter, 1)

      assert held(brewed, @blank_scroll) == 0
      assert held(brewed, @red_blood) == 0
      assert held(brewed, @fire_converter) == 1
    end

    # The whole point of re-validating: the client answers at its leisure, and the
    # materials may be gone by then (traded, dropped, used).
    test "brews nothing when the materials were spent between offer and reply" do
      assert {:ok, staged} = full_caster_cast()
      assert @fire_converter in staged.pending_menu_offer.entry_ids

      drained = %{staged | inventory: %{}}

      assert {:error, :no_materials} = SaCreatecon.on_menu_reply(drained, @fire_converter, 1)
    end

    test "brews nothing when only one half of the recipe survives" do
      state = caster([{@blank_scroll, 1}])

      assert {:error, :no_materials} = SaCreatecon.on_menu_reply(state, @fire_converter, 1)
      assert held(state, @fire_converter) == 0
    end

    # A partial consume would destroy the scroll and hand back nothing.
    test "consumes no material when the recipe cannot be completed" do
      state = caster([{@blank_scroll, 1}])

      assert {:error, :no_materials} = SaCreatecon.on_menu_reply(state, @fire_converter, 1)
      assert held(state, @blank_scroll) == 1
    end

    test "consumes only the chosen converter's material, leaving the others" do
      state =
        caster([
          {@blank_scroll, 1},
          {@red_blood, 1},
          {@crystal_blue, 1},
          {@green_live, 1},
          {@wind_of_verdure, 1}
        ])

      assert {:ok, brewed} = SaCreatecon.on_menu_reply(state, @earth_converter, 1)

      assert held(brewed, @green_live) == 0
      assert held(brewed, @earth_converter) == 1
      assert held(brewed, @red_blood) == 1
      assert held(brewed, @crystal_blue) == 1
      assert held(brewed, @wind_of_verdure) == 1
    end

    test "brews the converter the reply names, across all four recipes" do
      for {converter, material} <- [
            {@fire_converter, @red_blood},
            {@water_converter, @crystal_blue},
            {@earth_converter, @green_live},
            {@wind_converter, @wind_of_verdure}
          ] do
        state = caster([{@blank_scroll, 1}, {material, 1}])

        assert {:ok, brewed} = SaCreatecon.on_menu_reply(state, converter, 1)
        assert held(brewed, converter) == 1
        assert held(brewed, material) == 0
      end
    end

    # Only the surplus is spared: 1 scroll per brew, never the whole stack.
    test "consumes exactly one of each material, leaving the rest of the stack" do
      state = caster([{@blank_scroll, 5}, {@red_blood, 3}])

      assert {:ok, brewed} = SaCreatecon.on_menu_reply(state, @fire_converter, 1)

      assert held(brewed, @blank_scroll) == 4
      assert held(brewed, @red_blood) == 2
    end
  end

  defp held(state, nameid), do: ItemContainer.held_amount(state.inventory, nameid)
end
