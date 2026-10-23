defmodule Aesir.ZoneServer.Script.DslItemCountsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  @stone 7049

  defmodule StubSession do
    use GenServer

    def start_link(test), do: GenServer.start_link(__MODULE__, test)

    @impl true
    def init(test), do: {:ok, test}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, test) do
      send(test, {:script_apply, op})
      {:reply, {:ok, %PlayerState{character_id: 1}}, test}
    end
  end

  setup do
    stub(Items, :by_id, fn
      @stone -> {:ok, %ItemDefinition{id: @stone, aegis_name: "Stone", name: "Stone", type: :etc}}
      _other -> :error
    end)

    {:ok, session} = StubSession.start_link(self())
    signed = ItemCraft.to_map(ItemCraft.signed(5))

    inventory = %{
      0 => %InventoryItem{nameid: @stone, amount: 2, identify: 1, craft: signed},
      1 => %InventoryItem{nameid: @stone, amount: 3, identify: 1}
    }

    ctx = %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: session,
      game_state: %PlayerState{character_id: 1, inventory: inventory},
      source: {:npc, :test}
    }

    %{ctx: ctx}
  end

  test "countitem2 matches a signed item by its card values", %{ctx: ctx} do
    assert Dsl.countitem2(ctx, @stone, 1, 0, 0, 254, 0, 5, 0) == 2
    assert Dsl.countitem2(ctx, @stone, 1, 0, 0, 0, 0, 0, 0) == 3
    assert Dsl.count_item(ctx, @stone) == 5
  end

  test "countitem3 also matches the options, and an unknown item or offline target counts 0", %{
    ctx: ctx
  } do
    assert Dsl.countitem3(ctx, @stone, 1, 0, 0, 0, 0, 0, 0, []) == 3
    assert Dsl.countitem3(ctx, @stone, 1, 0, 0, 0, 0, 0, 0, [%{id: 1, value: 1, param: 0}]) == 0
    assert Dsl.countitem2(ctx, 1, 1, 0, 0, 0, 0, 0, 0) == 0

    stub(UnitRegistry, :get_char_id_by_account, fn _ -> {:error, :not_found} end)
    assert Dsl.count_item(ctx, @stone, 300) == 0
  end

  test "delitem2 asks the session to delete by the exact attributes", %{ctx: ctx} do
    assert %Ctx{status: :ok} = Dsl.delitem2(ctx, @stone, 1, 1, 0, 0, 254, 0, 5, 0)

    assert_received {:script_apply,
                     {:delitem,
                      %{nameid: @stone, identify: 1, cards: [254, 0, 5, 0], options: nil}, 1}}
  end

  test "an unknown item or an offline target ends the script, a zero amount does nothing", %{
    ctx: ctx
  } do
    assert %Ctx{status: {:error, :unknown_item}} = Dsl.delitem(ctx, 1, 1)

    stub(UnitRegistry, :get_char_id_by_account, fn _ -> {:error, :not_found} end)
    assert %Ctx{status: {:error, :no_player}} = Dsl.delitem(ctx, @stone, 1, 300)

    assert %Ctx{status: :ok} = Dsl.delitem(ctx, @stone, 0)
    refute_received {:script_apply, _op}
  end
end
