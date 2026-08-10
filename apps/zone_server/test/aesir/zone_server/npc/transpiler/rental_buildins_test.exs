defmodule Aesir.ZoneServer.Npc.Transpiler.RentalBuildinsTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Npc.Transpiler.Codegen
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule ScriptSession do
    use GenServer

    def start_link(test_pid), do: GenServer.start_link(__MODULE__, test_pid)

    @impl true
    def init(test_pid), do: {:ok, test_pid}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, test_pid) do
      send(test_pid, {:script_apply, op})
      {:reply, {:ok, :unchanged}, test_pid}
    end
  end

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Items)
    Mimic.copy(InventoryOps)
    :ok
  end

  defp gen!(body, opts \\ []) do
    opts = Map.new(opts)

    {:ok, src} =
      Codegen.generate(body, %{
        module: Map.get(opts, :module, "Aesir.ZoneServer.Content.Npc.Payon.RentalTestNpc"),
        kind: :script,
        source: "test.txt:1",
        spawns: [%{map: "payon", x: 1, y: 2, dir: 3, sprite: 58, name: "Test"}],
        functions: %{}
      })

    assert {:ok, _} = Code.string_to_quoted(src)
    src
  end

  test "rentitem maps to give_item_rental" do
    src = gen!("rentitem 2101, 3600;")

    assert src =~ "give_item_rental(ctx, 2101, 3600)"
  end

  test "rentitem3 folds fixed attributes and option arrays into a rental grant" do
    module = Module.concat(__MODULE__, "Rentitem3#{System.unique_integer([:positive])}")

    src =
      gen!(
        """
        setarray .@opt_id[0], 1, 2;
        setarray .@opt_val[0], 50, 60;
        setarray .@opt_param[0], 7, 8;
        rentitem3 2101, 3600, 1, 7, 0, 4001, 4002, 4003, 4004, .@opt_id, .@opt_val, .@opt_param;
        """,
        module: inspect(module)
      )

    assert src =~ "give_item_rental(ctx, 2101, 3600"
    assert src =~ "refine: 7"
    assert src =~ "card0: 4001"
    assert src =~ "random_options:"
    assert src =~ "Map.new(\n          Enum.zip("

    Code.compile_string(src)
    on_exit(fn -> :code.delete(module) end)

    session = start_supervised!({ScriptSession, self()})

    ctx = %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: session,
      game_state: :unchanged,
      source: {:npc, :test_npc}
    }

    assert %{status: :ok} = module.on_talk(ctx)

    assert_received {:script_apply, {:give_item_rental, 2101, 3600, opts} = op}

    assert opts == [
             refine: 7,
             card0: 4001,
             card1: 4002,
             card2: 4003,
             card3: 4004,
             random_options: %{
               "1" => %{val: 50, parm: 7},
               "2" => %{val: 60, parm: 8}
             }
           ]

    definition = %ItemDefinition{id: 2101, aegis_name: "Sword", name: "Sword", type: :weapon}
    stub(Items, :by_id, fn 2101 -> {:ok, definition} end)

    expect(InventoryOps, :add, fn 1, %{}, %{}, ^definition, 1, opts ->
      assert opts.refine == 7
      assert opts.card0 == 4001
      assert opts.card1 == 4002
      assert opts.card2 == 4003
      assert opts.card3 == 4004
      assert opts.random_options == %{"1" => %{val: 50, parm: 7}, "2" => %{val: 60, parm: 8}}
      assert opts.expire_time != nil

      item = %InventoryItem{
        nameid: 2101,
        amount: 1,
        refine: opts.refine,
        card0: opts.card0,
        card1: opts.card1,
        card2: opts.card2,
        card3: opts.card3,
        random_options: opts.random_options,
        expire_time: opts.expire_time
      }

      {:ok, %{0 => item}, {:added, 0, item}}
    end)

    assert {{:ok, %{inventory: %{0 => item}}}, _state} =
             ScriptEffectHandler.apply_op(op, rental_state())

    assert item.expire_time != nil
  end

  test "rentitem3 with an unsupported arity remains a raising stub" do
    module = Module.concat(__MODULE__, "InvalidRentitem3#{System.unique_integer([:positive])}")
    src = gen!("rentitem3 2101, 3600, 1;", module: inspect(module))

    assert src =~ "todo(ctx, :rentitem3, [2101, 3600, 1])"

    Code.compile_string(src)
    on_exit(fn -> :code.delete(module) end)

    assert_raise Aesir.ZoneServer.Script.NotImplementedError, fn ->
      module.on_talk(%Ctx{
        char_id: 1,
        account_id: 1,
        connection_pid: self(),
        game_state: :unchanged,
        source: {:npc, :test_npc}
      })
    end
  end

  defp rental_state do
    %{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1, inventory: %{}, stats: %{}}
    }
  end
end
