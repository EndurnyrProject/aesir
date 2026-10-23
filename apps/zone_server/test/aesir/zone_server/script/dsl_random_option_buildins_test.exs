defmodule Aesir.ZoneServer.Script.DslRandomOptionBuildinsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Option
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  # EQI_HAND_R and the right-hand equip bit.
  @hand_r 9
  @right_hand 2

  defmodule StubSession do
    use GenServer

    def start_link({test, reply}), do: GenServer.start_link(__MODULE__, {test, reply})

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, {test, reply} = state) do
      send(test, {:script_apply, op})
      {:reply, reply, state}
    end
  end

  defp ctx(opts \\ []) do
    options = Keyword.get(opts, :options, [%{id: 3, value: 7, param: 2}])
    sword = %InventoryItem{nameid: 1101, amount: 1, equip: @right_hand, random_options: options}

    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: Keyword.get(opts, :session),
      game_state: %PlayerState{character_id: 1, inventory: %{0 => sword}},
      source: {:npc, :test}
    }
  end

  describe "getequiprandomoption" do
    test "reads the slot's id, value or param, 0 for another type" do
      assert Dsl.getequiprandomoption(ctx(), @hand_r, 0, 0) == 3
      assert Dsl.getequiprandomoption(ctx(), @hand_r, 0, 1) == 7
      assert Dsl.getequiprandomoption(ctx(), @hand_r, 0, 2) == 2
      assert Dsl.getequiprandomoption(ctx(), @hand_r, 0, 3) == 0
      assert Dsl.getequiprandomoption(ctx(), @hand_r, 4, 0) == 0
    end

    test "an invalid index, an empty slot or an unknown player reads -1" do
      assert Dsl.getequiprandomoption(ctx(), @hand_r, 5, 0) == -1
      assert Dsl.getequiprandomoption(ctx(), @hand_r, -1, 0) == -1
      assert Dsl.getequiprandomoption(ctx(), 7, 0, 0) == -1
      assert Dsl.getequiprandomoption(ctx(), @hand_r, 0, 0, 999_999) == -1
    end

    test "a detached script ends" do
      assert_raise ArgumentError, fn ->
        Dsl.getequiprandomoption(%{ctx() | game_state: nil}, @hand_r, 0, 0)
      end
    end
  end

  describe "getrandomoptinfo" do
    test "reads 0 outside an option's script and ends a detached script" do
      assert Dsl.getrandomoptinfo(ctx(), 1) == 0

      assert_raise ArgumentError, fn ->
        Dsl.getrandomoptinfo(%{ctx() | game_state: nil}, 1)
      end
    end
  end

  describe "randomoptgroup" do
    test "rolls the group into the three local arrays, trailing zeros dropped" do
      entry = %Entry{option_id: 3, min: 4, max: 4, param: 0, chance: 10_000}

      stub(RandomOptions, :group, fn 7 ->
        {:ok, %Group{id: 7, name: "G", slots: [[entry]], max_random: 0, random: []}}
      end)

      rolled = Dsl.randomoptgroup(ctx(), 7)

      assert rolled.vars[:opt_id] == [3]
      assert rolled.vars[:opt_value] == [4]
      assert rolled.vars[:opt_param] == []
    end

    test "an unknown group stops the script" do
      stub(RandomOptions, :group, fn _id -> :error end)

      assert %Ctx{status: {:error, :unknown_random_option_group}} = Dsl.randomoptgroup(ctx(), 99)
    end
  end

  describe "setrandomoption" do
    setup do
      stub(RandomOptions, :option, fn
        3 -> {:ok, %Option{id: 3, name: "STR", program: []}}
        _id -> :error
      end)

      :ok
    end

    test "asks the player's session to set the slot and returns 1 when it does" do
      {:ok, session} = StubSession.start_link({self(), {:ok, %PlayerState{character_id: 1}}})

      assert {%Ctx{}, 1} = Dsl.setrandomoption(ctx(session: session), @hand_r, 1, 3, 70_000, 200)

      assert_received {:script_apply,
                       {:set_random_option, :right_hand, 1, %{id: 3, value: 4464, param: -56}}}
    end

    test "returns 0 when the session refuses" do
      {:ok, session} = StubSession.start_link({self(), {:error, :no_item}})

      assert {%Ctx{status: :ok}, 0} =
               Dsl.setrandomoption(ctx(session: session), @hand_r, 1, 3, 1, 0)
    end

    test "an unknown option, an invalid index or an unknown slot returns 0 without asking" do
      {:ok, session} = StubSession.start_link({self(), {:ok, %PlayerState{}}})
      ctx = ctx(session: session)

      assert {_ctx, 0} = Dsl.setrandomoption(ctx, @hand_r, 1, 4, 1, 0)
      assert {_ctx, 0} = Dsl.setrandomoption(ctx, @hand_r, 5, 3, 1, 0)
      assert {_ctx, 0} = Dsl.setrandomoption(ctx, 99, 1, 3, 1, 0)
      refute_received {:script_apply, _op}
    end

    test "a detached script ends" do
      assert {%Ctx{status: {:error, :no_player}}, 0} =
               Dsl.setrandomoption(
                 %{ctx() | session_pid: nil, game_state: nil},
                 @hand_r,
                 0,
                 3,
                 1,
                 0
               )
    end
  end
end
