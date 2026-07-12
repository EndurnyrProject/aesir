defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.TranspilerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :set_mimic_from_context

  setup do
    Mimic.copy(CharacterPersistence)
    Mimic.copy(StatusInterpreter)

    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(StatusInterpreter, :apply_status, fn _, _, _, _ -> :ok end)
    stub(StatusInterpreter, :remove_status, fn _, _, _ -> :ok end)

    :ok
  end

  describe "transpile/1" do
    test "a plain itemheal becomes a heal call" do
      assert {:ok, "heal(ctx, hp: 45)"} = Transpiler.transpile("itemheal 45,0;")
    end

    test "an unsupported command surfaces the codegen error unchanged" do
      assert {:error, {:unsupported, "produce"}} = Transpiler.transpile("produce 999,1;")
    end

    test "a truncated script surfaces the parse error unchanged" do
      assert {:error, {:parse_error, _}} = Transpiler.transpile("itemheal 45,")
    end
  end

  describe "golden set" do
    test "a plain potion" do
      assert {:ok, "heal(ctx, hp: 45)"} = Transpiler.transpile("itemheal 45,0;")
    end

    test "a condensed potion using rand" do
      assert {:ok, "heal(ctx, hp: 45..65)"} = Transpiler.transpile("itemheal rand(45,65),0;")
    end

    test "a fly wing" do
      assert {:ok, "warp(ctx, :random)"} = Transpiler.transpile("warp \"Random\",0,0;")
    end

    test "a butterfly wing" do
      assert {:ok, "warp(ctx, :save_point)"} = Transpiler.transpile("warp \"SavePoint\",0,0;")
    end

    test "a class-branch scroll" do
      script = "if (Class == Job_Knight) sc_start SC_BLESSING,60000,10; else itemheal 50,0;"

      expected =
        String.trim("""
        if (class(ctx) == :knight) do
          sc_start(ctx, :sc_blessing, 60000, 10)
        else
          heal(ctx, hp: 50)
        end
        """)

      assert {:ok, ^expected} = Transpiler.transpile(script)
    end

    test "an SKF food passes a negative val1 through unchanged" do
      assert {:ok, "sc_start(ctx, :sc_skf_cast, 600000, -5)"} =
               Transpiler.transpile("sc_start SC_SKF_CAST,600000,-5;")
    end
  end

  describe "transpile_equip/1" do
    test "a flat bonus becomes a bonus program" do
      assert {:ok, [{:bonus, :patk, 20}]} = Transpiler.transpile_equip("bonus bPAtk,20;")
    end

    test "an unsupported bonus2 statement surfaces the codegen error unchanged" do
      assert {:error, {:unsupported, {:unsupported_command, "bonus2"}}} =
               Transpiler.transpile_equip("bonus2 bAddRace,RC_Brute,10;")
    end

    test "a truncated script surfaces the parse error unchanged" do
      assert {:error, {:parse_error, _}} = Transpiler.transpile_equip("bonus bPAtk,")
    end
  end

  describe "end-to-end through ScriptCompiler" do
    test "a transpiled heal script raises hp at runtime" do
      assert {:ok, on_use} = Transpiler.transpile("itemheal 50,0;")
      assert ScriptCompiler.compile_all!([item_def(501, on_use)]) == :ok

      ctx = CompiledItemScripts.on_use(501, build_ctx(hp: 100))

      assert ctx.status == :ok
      assert ctx.game_state.stats.current_state.hp == 150
    end

    test "a transpiled class-branch scroll compiles and runs the matching branch" do
      script = "if (Class == Job_Knight) sc_start SC_BLESSING,60000,10; else itemheal 50,0;"

      assert {:ok, on_use} = Transpiler.transpile(script)
      assert ScriptCompiler.compile_all!([item_def(502, on_use)]) == :ok

      ctx = CompiledItemScripts.on_use(502, build_ctx(hp: 100))

      assert ctx.status == :ok
      assert ctx.game_state.stats.current_state.hp == 150
    end
  end

  defp item_def(id, on_use) do
    %ItemDefinition{id: id, aegis_name: "Item_#{id}", name: "Item #{id}", on_use: on_use}
  end

  defp build_ctx(opts) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state: build_game_state(opts),
      source: {:item, 501}
    }
  end

  defp build_game_state(opts) do
    stats = %Stats{
      current_state: %CurrentState{
        hp: Keyword.get(opts, :hp, 100),
        sp: Keyword.get(opts, :sp, 10)
      },
      derived_stats: %DerivedStats{max_hp: 500, max_sp: 200, aspd: 150},
      progression: %PlayerProgression{base_level: 10, job_level: 3, job_id: 0}
    }

    %PlayerState{
      character_id: 1,
      account_id: 100,
      sex: "M",
      x: 50,
      y: 50,
      map_name: "prontera",
      stats: stats,
      inventory: %{}
    }
  end
end
