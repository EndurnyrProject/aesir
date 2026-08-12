defmodule Aesir.ZoneServer.Script.DslSetlookTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @char_id 1_004
  @hair 3
  @hair_color 6
  @clothes_color 2
  @head_bottom 7
  @head_mid 4
  @robe 6
  defmodule StubSession do
    use GenServer

    def start_link(reply_fun), do: GenServer.start_link(__MODULE__, reply_fun)

    @impl true
    def init(reply_fun), do: {:ok, reply_fun}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, reply_fun) do
      send(:dsl_setlook_probe, {:script_apply, op})
      {:reply, reply_fun.(op), reply_fun}
    end
  end

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Aesir.TestProbe.register!(:dsl_setlook_probe)
    :ok
  end

  describe "getlook/2" do
    test "reads the persisted appearance fields for cosmetic look types" do
      ctx = register_player()

      assert Dsl.getlook(ctx, 1) == @hair
      assert Dsl.getlook(ctx, 6) == @hair_color
      assert Dsl.getlook(ctx, 7) == @clothes_color
      assert Dsl.getlook(ctx, 3) == @head_bottom
      assert Dsl.getlook(ctx, 5) == @head_mid
      assert Dsl.getlook(ctx, 12) == @robe
    end

    test "reads the equipment views for weapon, head_top and shield look types" do
      ctx = register_player()

      # No equipment worn -> the equipment views are all 0.
      assert Dsl.getlook(ctx, 2) == 0
      assert Dsl.getlook(ctx, 4) == 0
      assert Dsl.getlook(ctx, 8) == 0
    end

    test "returns -1 for look types with no Aesir representation or unknown ids" do
      ctx = register_player()

      for type <- [0, 9, 10, 11, 13, 99] do
        assert Dsl.getlook(ctx, type) == -1
      end
    end

    test "raises on a detached context" do
      detached = %{register_player() | game_state: nil}

      assert_raise ArgumentError, ~r/getlook\/2/, fn -> Dsl.getlook(detached, 1) end
    end
  end

  describe "setlook/3" do
    test "routes the clamped look change through the session and folds back the reply" do
      session = start_session(fn _op -> {:ok, %PlayerState{hair: 99}} end)
      ctx = register_player(session)

      assert Dsl.setlook(ctx, 1, 5) == %{ctx | game_state: %PlayerState{hair: 99}}
      assert_receive {:script_apply, {:set_look, 1, 5}}
    end

    test "clamps hair/color/cloth to the rAthena default ranges and negatives to zero" do
      session = start_session(fn _op -> {:ok, %PlayerState{}} end)
      ctx = register_player(session)

      Dsl.setlook(ctx, 1, 99)
      assert_receive {:script_apply, {:set_look, 1, 23}}

      Dsl.setlook(ctx, 6, 99)
      assert_receive {:script_apply, {:set_look, 6, 9}}

      Dsl.setlook(ctx, 7, 42)
      assert_receive {:script_apply, {:set_look, 7, 4}}

      Dsl.setlook(ctx, 1, -5)
      assert_receive {:script_apply, {:set_look, 1, 0}}
    end

    test "leaves head and robe slots unclamped but non-negative" do
      session = start_session(fn _op -> {:ok, %PlayerState{}} end)
      ctx = register_player(session)

      Dsl.setlook(ctx, 3, -2)
      assert_receive {:script_apply, {:set_look, 3, 0}}

      Dsl.setlook(ctx, 12, 300)
      assert_receive {:script_apply, {:set_look, 12, 300}}
    end

    test "warns and ignores look types with no settable state" do
      reject(&PlayerSession.script_apply/2)
      ctx = register_player()

      log =
        capture_log(fn ->
          assert Dsl.setlook(ctx, 9, 3) == ctx
        end)

      assert log =~ "setlook"
      refute_received {:script_apply, _}
    end

    test "halts on a detached context" do
      detached = %{register_player() | game_state: nil}
      assert Dsl.setlook(detached, 1, 5).status == {:error, :no_player}
    end

    test "errored context short-circuits" do
      ctx = Ctx.halt(register_player(), :boom)
      assert Dsl.setlook(ctx, 1, 5) == ctx
      refute_received {:script_apply, _}
    end
  end

  defp start_session(reply_fun) do
    start_supervised!({StubSession, reply_fun})
  end

  defp setup_ets_tables(context), do: Aesir.TestEtsSetup.setup_ets_tables(context)

  defp register_player(session_pid \\ nil) do
    player =
      %Character{
        id: @char_id,
        account_id: @char_id,
        name: "SetlookTarget",
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        class: 0,
        base_level: 1,
        job_level: 1,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hair: @hair,
        hair_color: @hair_color,
        clothes_color: @clothes_color,
        head_bottom: @head_bottom,
        head_mid: @head_mid,
        robe: @robe
      }
      |> PlayerState.new()

    :ok = UnitRegistry.register_unit(:player, @char_id, PlayerState, player, self())

    %Ctx{
      char_id: @char_id,
      account_id: @char_id,
      connection_pid: self(),
      session_pid: session_pid,
      game_state: player,
      source: {:npc, __MODULE__}
    }
  end
end
