defmodule Aesir.ZoneServer.Script.DslEquipReadsTest do
  @moduledoc """
  Covers the equip/item read buildins: `getequipisequiped`, `getequiprefinerycnt`,
  `getequipname`, `getequipweaponlv`, `getequiparmorlv`, `getequipisenableref`,
  `getequippercentrefinery`, `getequiprefinecost`, `getiteminfo` and `isequippedcnt`.

  Uses the real item catalog and refine tables (loaded at zone boot, as in
  `dsl_refine_test.exs`); `ItemManagement` is the Mimic-copied real module, so
  lookups resolve against `priv/db/items` and `priv/db/refine`.
  """

  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # A stand-in session that answers {:script_apply, op}, forwarding the op to
  # the test process. Mirrors DslRefineTest's StubSession.
  defmodule StubSession do
    use GenServer

    def start_link(reply_fun), do: GenServer.start_link(__MODULE__, reply_fun)

    @impl true
    def init(reply_fun), do: {:ok, reply_fun}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, reply_fun) do
      send(:dsl_equip_probe, {:script_apply, op})
      {:reply, reply_fun.(op), reply_fun}
    end
  end

  setup do
    Aesir.TestProbe.register!(:dsl_equip_probe)
    :ok
  end

  # Real ids from priv/db (same fixtures as DslRefineTest).
  # Sword: weapon-level-1 one-hand sword, refineable, amount 1 when worn.
  @sword 1101
  # Guard: a left-hand shield, armor type, armor-level 1, refineable.
  @guard 2101
  # Red Potion: not equipment, not refineable.
  @potion 501
  # Poring Card: a card type.
  @poring_card 4001

  @right_hand 9
  @left_hand 8
  @armor 7

  describe "getequipisequiped/2" do
    test "returns 1 when an item is worn in the slot, else 0" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02}})

      assert Dsl.getequipisequiped(ctx, @right_hand) == 1
      assert Dsl.getequipisequiped(ctx, @armor) == 0
      assert Dsl.getequipisequiped(ctx, 99) == 0
    end
  end

  describe "getequiprefinerycnt/2" do
    test "returns the refine level of the item worn in the slot" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02, refine: 7}})

      assert Dsl.getequiprefinerycnt(ctx, @right_hand) == 7
    end

    test "returns 0 for an empty or unknown slot" do
      ctx = build_ctx(inventory: %{})

      assert Dsl.getequiprefinerycnt(ctx, @right_hand) == 0
      assert Dsl.getequiprefinerycnt(ctx, 99) == 0
    end
  end

  describe "getequipname/2" do
    test "returns the display name of the item worn in the slot" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02}})

      assert Dsl.getequipname(ctx, @right_hand) == "Sword"
    end

    test "returns an empty string for an empty or unknown slot" do
      ctx = build_ctx(inventory: %{})

      assert Dsl.getequipname(ctx, @right_hand) == ""
      assert Dsl.getequipname(ctx, 99) == ""
    end
  end

  describe "getequipweaponlv/2" do
    test "returns the weapon level of a worn weapon" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02}})

      assert Dsl.getequipweaponlv(ctx, @right_hand) == 1
    end

    test "returns 0 for a worn non-weapon, an empty slot, or an unknown slot" do
      # A shield (armor type) worn in the left hand.
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @guard, equip: 0x20}})

      assert Dsl.getequipweaponlv(ctx, @left_hand) == 0
      assert Dsl.getequipweaponlv(ctx, 99) == 0

      empty = build_ctx(inventory: %{})
      assert Dsl.getequipweaponlv(empty, @right_hand) == 0
    end
  end

  describe "getequiparmorlv/2" do
    test "returns the armor level of a worn armor" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @guard, equip: 0x20}})

      assert Dsl.getequiparmorlv(ctx, @left_hand) == 1
    end

    test "returns 0 for a worn weapon, an empty slot, or an unknown slot" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02}})

      assert Dsl.getequiparmorlv(ctx, @right_hand) == 0
      assert Dsl.getequiparmorlv(ctx, 99) == 0
    end
  end

  describe "getequipisenableref/2" do
    test "returns 1 for a refinable, non-rented worn item" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02}})

      assert Dsl.getequipisenableref(ctx, @right_hand) == 1
    end

    test "returns 0 for a worn non-refinable, rented, empty, or unknown slot" do
      # A rented copy is not refinable.
      rented =
        build_ctx(
          inventory: %{
            0 => %InventoryItem{nameid: @sword, equip: 0x02, expire_time: ~N[2030-01-01 00:00:00]}
          }
        )

      assert Dsl.getequipisenableref(rented, @right_hand) == 0

      # A potion is not equipment/refinable.
      potion = build_ctx(inventory: %{0 => %InventoryItem{nameid: @potion, equip: 0x02}})
      assert Dsl.getequipisenableref(potion, @right_hand) == 0

      empty = build_ctx(inventory: %{})
      assert Dsl.getequipisenableref(empty, @right_hand) == 0
      assert Dsl.getequipisenableref(empty, 99) == 0
    end
  end

  describe "getequippercentrefinery/3" do
    test "returns the next-attempt success rate for a +0 weapon at the normal cost" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02, refine: 0}})

      assert Dsl.getequippercentrefinery(ctx, @right_hand) == 100
      assert Dsl.getequippercentrefinery(ctx, @right_hand, 0) == 100
    end

    test "returns 0 for an empty slot, a non-refinable item, or an unknown slot" do
      empty = build_ctx(inventory: %{})

      assert Dsl.getequippercentrefinery(empty, @right_hand) == 0
      assert Dsl.getequippercentrefinery(empty, 99) == 0
    end
  end

  describe "getequiprefinecost/4" do
    test "returns the material id and zeny cost for the next normal refine" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02, refine: 0}})

      assert Dsl.getequiprefinecost(ctx, @right_hand, :normal, :material_id) == 1010
      assert Dsl.getequiprefinecost(ctx, @right_hand, :normal, :zeny_cost) > 0
    end

    test "returns -1 for an empty slot, unknown cost variant, or unknown info" do
      empty = build_ctx(inventory: %{})

      assert Dsl.getequiprefinecost(empty, @right_hand, :normal, :material_id) == -1
      assert Dsl.getequiprefinecost(empty, 99, :normal, :material_id) == -1
    end

    test "returns -1 for an unsupported info selector" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02, refine: 0}})

      assert Dsl.getequiprefinecost(ctx, @right_hand, :normal, :blessing_amount) == -1
    end
  end

  describe "getiteminfo/3" do
    test "reads modelled integer fields by ITEMINFO code" do
      ctx = build_ctx()

      # ID (17), weapon level (13), IT_WEAPON (2), subtype (20), weight (6).
      assert Dsl.getiteminfo(ctx, @sword, 17) == @sword
      assert Dsl.getiteminfo(ctx, @sword, 13) == 1
      assert Dsl.getiteminfo(ctx, @sword, 2) == 5
      assert Dsl.getiteminfo(ctx, @sword, 20) == 2
      assert Dsl.getiteminfo(ctx, @sword, 6) == 500
    end

    test "reads armor level from an armor and returns 0 from a weapon" do
      ctx = build_ctx()

      assert Dsl.getiteminfo(ctx, @guard, 19) == 1
      assert Dsl.getiteminfo(ctx, @sword, 19) == 0
      assert Dsl.getiteminfo(ctx, @sword, 13) == 1
    end

    test "resolves a string Aegis name and returns AEGISNAME as a string" do
      ctx = build_ctx()

      assert Dsl.getiteminfo(ctx, "Sword", 17) == @sword
      assert Dsl.getiteminfo(ctx, @sword, 18) == "Sword"
    end

    test "returns -1 for fields Aesir does not model and unknown items/types" do
      ctx = build_ctx()

      assert Dsl.getiteminfo(ctx, @sword, 3) == -1
      assert Dsl.getiteminfo(ctx, @sword, 4) == -1
      assert Dsl.getiteminfo(ctx, @sword, 14) == -1
      assert Dsl.getiteminfo(ctx, 9_999_999, 17) == -1
      assert Dsl.getiteminfo(ctx, @sword, 99) == -1
    end

    test "works on a detached ctx (no player needed)" do
      assert Dsl.getiteminfo(detached_ctx(), @sword, 17) == @sword
    end
  end

  describe "isequippedcnt/2" do
    test "counts equipped copies of a non-card id" do
      ctx =
        build_ctx(
          inventory: %{
            0 => %InventoryItem{nameid: @sword, equip: 0x02, amount: 1},
            1 => %InventoryItem{nameid: @sword, equip: 0x20, amount: 1}
          }
        )

      assert Dsl.isequippedcnt(ctx, [@sword]) == 2
      assert Dsl.isequippedcnt(ctx, [@sword, @sword]) == 2
      assert Dsl.isequippedcnt(ctx, [9999]) == 0
    end

    test "counts each equipped card slot holding a card id" do
      ctx =
        build_ctx(
          inventory: %{
            0 => %InventoryItem{
              nameid: @guard,
              equip: 0x20,
              amount: 1,
              card0: @poring_card,
              card1: @poring_card,
              card2: 0
            }
          }
        )

      assert Dsl.isequippedcnt(ctx, [@poring_card]) == 2
      assert Dsl.isequippedcnt(ctx, [@poring_card, 9999]) == 2
    end
  end

  describe "detached ctx" do
    test "equip reads raise on a detached ctx" do
      detached = detached_ctx()

      assert_raise ArgumentError, fn -> Dsl.getequipisequiped(detached, @right_hand) end
      assert_raise ArgumentError, fn -> Dsl.getequiprefinerycnt(detached, @right_hand) end
      assert_raise ArgumentError, fn -> Dsl.getequipname(detached, @right_hand) end
      assert_raise ArgumentError, fn -> Dsl.getequipweaponlv(detached, @right_hand) end
      assert_raise ArgumentError, fn -> Dsl.getequiparmorlv(detached, @right_hand) end
      assert_raise ArgumentError, fn -> Dsl.getequipisenableref(detached, @right_hand) end
      assert_raise ArgumentError, fn -> Dsl.getequippercentrefinery(detached, @right_hand) end

      assert_raise ArgumentError, fn ->
        Dsl.getequiprefinecost(detached, @right_hand, :normal, :material_id)
      end

      assert_raise ArgumentError, fn -> Dsl.isequippedcnt(detached, [@sword]) end
    end
  end

  describe "statement ops" do
    test "getitem2 routes a {:give_item2, ...} op with the attribute map through the session" do
      session = start_stub(fn _op -> {:ok, %PlayerState{}} end)
      ctx = build_ctx(session: session)

      Dsl.getitem2(ctx, @sword, 1, 1, 4, 0, 0, @poring_card, 0, 0, 0)

      assert_received {:script_apply,
                       {:give_item2, @sword, 1,
                        %{
                          identify: 1,
                          refine: 4,
                          card0: @poring_card,
                          card1: 0,
                          card2: 0,
                          card3: 0
                        }}}
    end

    test "delequip resolves the equipped index and routes a {:delequip, index, nameid} op" do
      session = start_stub(fn _op -> {:ok, %PlayerState{}} end)

      ctx =
        build_ctx(
          session: session,
          inventory: %{0 => %InventoryItem{nameid: @sword, equip: 0x02, amount: 1}}
        )

      Dsl.delequip(ctx, @right_hand)
      assert_received {:script_apply, {:delequip, 0, @sword}}
    end

    test "delequip routes nothing for an empty slot" do
      session = start_stub(fn _op -> {:ok, %PlayerState{}} end)
      ctx = build_ctx(session: session, inventory: %{})

      assert Dsl.delequip(ctx, @right_hand) == ctx
      refute_received {:script_apply, _}
    end
  end

  defp start_stub(reply_fun) do
    {:ok, pid} = StubSession.start_link(reply_fun)
    pid
  end

  defp detached_ctx do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state: nil,
      source: {:item, @potion}
    }
  end

  defp build_ctx(opts \\ []) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: Keyword.get(opts, :session),
      game_state: %PlayerState{inventory: Keyword.get(opts, :inventory, %{})},
      source: {:item, @potion}
    }
  end
end
