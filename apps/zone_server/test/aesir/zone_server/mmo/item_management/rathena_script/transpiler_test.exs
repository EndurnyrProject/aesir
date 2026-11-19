defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.TranspilerTest do
  # ScriptCompiler.compile_all!/1 redefines the global CompiledItemScripts module.
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Script.Ctx

  setup :set_mimic_from_context

  setup do
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(StatusInterpreter, :apply_status, fn _, _, _, _ -> :ok end)
    stub(StatusInterpreter, :remove_status, fn _, _, _ -> :ok end)

    :ok
  end

  describe "transpile/1" do
    test "an unsupported command surfaces the codegen error unchanged" do
      assert {:error, {:unsupported, "cooking"}} = Transpiler.transpile("cooking 11;")
    end

    test "a truncated script surfaces the parse error unchanged" do
      assert {:error, {:parse_error, _}} = Transpiler.transpile("itemheal 45,")
    end
  end

  describe "golden set" do
    test "a class-branch scroll" do
      script = "if (Class == Job_Knight) sc_start SC_BLESSING,60000,10; else itemheal 50,0;"

      expected =
        String.trim("""
        if (class(ctx) == :knight) do
          sc_start(ctx, :sc_blessing, 60000, 10)
        else
          item_heal(ctx, hp: 50)
        end
        """)

      assert {:ok, ^expected} = Transpiler.transpile(script)
    end

    test "the optional itemskill requirement flag survives transpilation" do
      assert {:ok, "itemskill(ctx, 19, level: 1, keep_requirement: true)"} =
               Transpiler.transpile(~s(itemskill "MG_FIREBOLT",1,true;))

      assert {:ok, "itemskill(ctx, 19, level: 1, keep_requirement: true)"} =
               Transpiler.transpile(~s(itemskill "MG_FIREBOLT",1,2;))

      assert {:ok, "itemskill(ctx, 19, level: 1, keep_requirement: false)"} =
               Transpiler.transpile(~s(itemskill "MG_FIREBOLT",1,0;))
    end

    test "produce transpiles the production list trigger" do
      assert {:ok, "produce(ctx, 21)"} = Transpiler.transpile("produce 21;")
    end

    test "unitskilluseid transpiles the script's own player cast" do
      assert {:ok, "unitskilluseid(ctx, 10015, level: 2)"} =
               Transpiler.transpile(~s{unitskilluseid getcharid(3),"GD_ITEMEMERGENCYCALL",2;})

      assert {:ok, "unitskilluseid(ctx, 34, level: 7)"} =
               Transpiler.transpile(~s{unitskilluseid getcharid(3),"AL_BLESSING",7;})
    end

    test "unitskilluseid refuses a unit id that is not the script's player" do
      assert {:error, {:unsupported, {:unit_skill_use_target, _expr}}} =
               Transpiler.transpile(~s{unitskilluseid getcharid(0),"AL_BLESSING",7;})
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

    test "a bonus2 damage-tier statement becomes a bonus program" do
      assert {:ok, [{:bonus, {:addrace, :brute}, 10}]} =
               Transpiler.transpile_equip("bonus2 bAddRace,RC_Brute,10;")
    end

    test "an unsupported bonus2 statement surfaces the codegen error unchanged" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bMaxHP"}}} =
               Transpiler.transpile_equip("bonus2 bMaxHP,RC_Brute,10;")
    end

    test "a truncated script surfaces the parse error unchanged" do
      assert {:error, {:parse_error, _}} = Transpiler.transpile_equip("bonus bPAtk,")
    end
  end

  describe "end-to-end through ScriptCompiler" do
    test "Falcon Flute toggles only with Falconry Mastery and no wug" do
      script =
        ~S|if (getskilllv("HT_FALCON")) { if (!checkoption(Option_Wug) && !checkoption(Option_Wugrider)) setfalcon (!checkfalcon()); }|

      assert {:ok, on_use} = Transpiler.transpile(script)
      item = build(:item_definition, on_use: on_use)
      assert :ok = ScriptCompiler.compile_all!([item])

      ctx = item_ctx(item, build(:player_state, stats: %{progression: %{learned_skills: %{}}}))
      assert CompiledItemScripts.on_use(item.id, ctx) == ctx

      learned = put_in(ctx.game_state.stats.progression.learned_skills, %{127 => 1})
      assert CompiledItemScripts.on_use(item.id, learned).session_effects == [{:falcon, true}]

      equipped = put_in(learned.game_state.option, Option.id(:falcon))
      assert CompiledItemScripts.on_use(item.id, equipped).session_effects == [{:falcon, false}]

      for option <- [:wug, :wugrider] do
        mounted = put_in(learned.game_state.option, Option.id(option))
        assert CompiledItemScripts.on_use(item.id, mounted) == mounted
      end
    end

    test "a transpiled class-branch scroll compiles and runs the matching branch" do
      script = "if (Class == Job_Knight) sc_start SC_BLESSING,60000,10; else itemheal 50,0;"

      assert {:ok, on_use} = Transpiler.transpile(script)
      item = build(:item_definition, on_use: on_use)
      assert ScriptCompiler.compile_all!([item]) == :ok

      novice =
        build(:player_state,
          stats: %{
            base_stats: %{vit: 0, int: 0},
            current_state: %{hp: 100},
            derived_stats: %{max_hp: 500},
            progression: %{job_id: 0}
          }
        )

      ctx = CompiledItemScripts.on_use(item.id, item_ctx(item, novice))

      assert ctx.status == :ok
      assert ctx.game_state.stats.current_state.hp == 150
    end
  end

  defp item_ctx(item, player) do
    %Ctx{
      char_id: player.character_id,
      account_id: player.account_id,
      connection_pid: self(),
      game_state: player,
      source: {:item, item.id}
    }
  end
end
