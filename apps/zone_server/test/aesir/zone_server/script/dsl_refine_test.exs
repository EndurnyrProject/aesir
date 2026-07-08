defmodule Aesir.ZoneServer.Script.DslRefineTest do
  @moduledoc """
  Covers the Task 9 refine DSL surface: the pure reads (`refine_targets/1`,
  `refinable?/2`, `refine_rate/3`, `refine_cost/3`) over `ctx.game_state` +
  `RefineDatabase`, and `refine/4` — which, unlike other effect ops, returns
  the tagged `RefineOps` outcome directly instead of folding an updated `ctx`,
  routed through `{:script_apply, {:refine, ...}}`. The real mutation through
  `RefineOps` is covered separately (DataCase, the real path).
  """

  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Real item ids from priv/db/items (same fixtures as RefineOpsTest).
  # Sword: weapon_level 1, refineable.
  @sword 1101
  # Phracon: the weapon-lv1 "normal" ore (refine.yml).
  @phracon 1010
  # Red Potion: not equipment, not refineable.
  @potion 501

  # A stand-in session that answers {:script_apply, op}, forwarding the op to
  # the test process. Mirrors DslEconomyTest's StubSession.
  defmodule StubSession do
    use GenServer

    def start_link(reply_fun), do: GenServer.start_link(__MODULE__, reply_fun)

    @impl true
    def init(reply_fun), do: {:ok, reply_fun}

    @impl true
    def handle_call({:script_apply, op}, {from_pid, _tag}, reply_fun) do
      send(:dsl_refine_probe, {:script_apply, op})
      {:reply, reply_fun.(op, from_pid), reply_fun}
    end
  end

  setup do
    Process.register(self(), :dsl_refine_probe)
    :ok
  end

  describe "refine_targets/1" do
    test "lists a refinable equip with index/nameid/name/refine/refinable?" do
      ctx =
        build_ctx(
          inventory: %{
            0 => %InventoryItem{nameid: @sword, refine: 5},
            1 => %InventoryItem{nameid: @potion, amount: 1}
          }
        )

      assert Dsl.refine_targets(ctx) == [
               %{index: 0, nameid: @sword, name: "Sword", refine: 5, refinable?: true}
             ]
    end

    test "marks a maxed-out item as not currently refinable" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, refine: 20}})

      assert [%{refinable?: false}] = Dsl.refine_targets(ctx)
    end

    test "ignores an unknown item id without raising" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: 9_999_999, refine: 0}})

      assert Dsl.refine_targets(ctx) == []
    end
  end

  describe "refinable?/2" do
    test "true for a refinable item below MAX_REFINE" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, refine: 0}})

      assert Dsl.refinable?(ctx, 0)
    end

    test "false for a non-refinable item, a maxed item, or a missing index" do
      ctx =
        build_ctx(
          inventory: %{
            0 => %InventoryItem{nameid: @potion, refine: 0},
            1 => %InventoryItem{nameid: @sword, refine: 20}
          }
        )

      refute Dsl.refinable?(ctx, 0)
      refute Dsl.refinable?(ctx, 1)
      refute Dsl.refinable?(ctx, 99)
    end
  end

  describe "refine_rate/3" do
    test "returns the yml Rate/100 for the process lookup at refine + 1" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, refine: 0}})

      assert Dsl.refine_rate(ctx, 0, :normal) == 100
    end

    test "returns 0 for a non-refinable item, a maxed item, or a missing index" do
      ctx =
        build_ctx(
          inventory: %{
            0 => %InventoryItem{nameid: @potion, refine: 0},
            1 => %InventoryItem{nameid: @sword, refine: 20}
          }
        )

      assert Dsl.refine_rate(ctx, 0, :normal) == 0
      assert Dsl.refine_rate(ctx, 1, :normal) == 0
      assert Dsl.refine_rate(ctx, 99, :normal) == 0
    end
  end

  describe "refine_cost/3" do
    test "returns the ore/zeny/blessing cost from the process level_info" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, refine: 0}})

      assert Dsl.refine_cost(ctx, 0, :normal) == %{
               ore_nameid: @phracon,
               ore_amount: 1,
               zeny: 50,
               blessing_amount: 0
             }
    end

    test "returns an all-zero cost when the item is not refinable" do
      ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @potion, refine: 0}})

      assert Dsl.refine_cost(ctx, 0, :normal) == %{
               ore_nameid: nil,
               ore_amount: 0,
               zeny: 0,
               blessing_amount: 0
             }
    end
  end

  describe "refine/4 routing" do
    test "captures the expected nameid at index and returns the tagged result unmodified" do
      session = start_stub(fn _op, _from -> {:ok, :success, 8} end)

      ctx =
        build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword, refine: 7}}, session: session)

      assert Dsl.refine(ctx, 0, :enriched, false) == {:ok, :success, 8}
      assert_received {:script_apply, {:refine, 0, @sword, :enriched, false}}
    end

    test "passes every tagged shape through unmodified" do
      for reply <- [{:ok, :broke}, {:ok, :downgrade, 6}, {:ok, :fail}, {:error, :no_ore}] do
        session = start_stub(fn _op, _from -> reply end)
        ctx = build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword}}, session: session)

        assert Dsl.refine(ctx, 0, :normal, false) == reply
      end
    end

    test "rejects a missing index without a session round-trip" do
      session = start_stub(fn _op, _from -> flunk("must not route a missing item") end)
      ctx = build_ctx(inventory: %{}, session: session)

      assert Dsl.refine(ctx, 0, :normal, false) == {:error, :no_item}
      refute_received {:script_apply, _}
    end

    test "short-circuits an already-halted ctx without a session round-trip" do
      session = start_stub(fn _op, _from -> flunk("must not route a halted ctx") end)

      ctx =
        build_ctx(inventory: %{0 => %InventoryItem{nameid: @sword}}, session: session)
        |> Ctx.halt(:already_dead)

      assert Dsl.refine(ctx, 0, :normal, false) == {:error, :already_dead}
      refute_received {:script_apply, _}
    end
  end

  defp start_stub(reply_fun) do
    {:ok, pid} = StubSession.start_link(reply_fun)
    pid
  end

  defp build_ctx(opts) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: Keyword.get(opts, :session, self()),
      game_state: build_game_state(opts),
      source: {:npc, :test_npc}
    }
  end

  defp build_game_state(opts) do
    %PlayerState{
      character_id: 1,
      account_id: 100,
      inventory: Keyword.get(opts, :inventory, %{})
    }
  end
end
