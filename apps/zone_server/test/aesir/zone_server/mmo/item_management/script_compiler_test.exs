defmodule Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompilerTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureIO

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
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

  test "compile_all!/1 returns :ok, defines CompiledItemScripts, and a healing script raises hp" do
    assert ScriptCompiler.compile_all!([item_def(501, "heal(ctx, hp: 50)")]) == :ok

    assert function_exported?(CompiledItemScripts, :on_use, 2)

    ctx = CompiledItemScripts.on_use(501, build_ctx(hp: 100))

    assert ctx.status == :ok
    assert ctx.game_state.stats.current_state.hp == 150
  end

  test "the noop fallback returns the ctx unchanged for an unknown item id" do
    assert ScriptCompiler.compile_all!([item_def(501, "heal(ctx, hp: 50)")]) == :ok

    ctx = build_ctx()

    assert CompiledItemScripts.on_use(999_999, ctx) == ctx
  end

  test "a malformed on_use makes compile_all!/1 raise" do
    assert_raise TokenMissingError, fn ->
      ScriptCompiler.compile_all!([item_def(501, "heal(ctx,")])
    end
  end

  test "an on_use calling an undefined DSL fn makes compile_all!/1 raise" do
    capture_io(:stderr, fn ->
      assert_raise CompileError, fn ->
        ScriptCompiler.compile_all!([item_def(501, "no_such_dsl_fn(ctx)")])
      end
    end)
  end

  test "a conditional multi-line on_use compiles and dispatches the right branch" do
    test_pid = self()

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_blessing, params ->
      send(test_pid, {:applied, params})
      :ok
    end)

    source = """
    if class(ctx) == :novice do
      sc_start(ctx, :sc_blessing, 60_000, 10)
    else
      cure(ctx, :sc_blessing)
    end
    """

    assert ScriptCompiler.compile_all!([item_def(502, source)]) == :ok

    ctx = CompiledItemScripts.on_use(502, build_ctx())

    assert ctx.status == :ok
    assert_received {:applied, params}
    assert params[:val1] == 10
    assert params[:duration] == 60_000
  end

  defp item_def(id, on_use) do
    %ItemDefinition{id: id, aegis_name: "Item_#{id}", name: "Item #{id}", on_use: on_use}
  end

  defp build_ctx(opts \\ []) do
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
      base_stats: %{vit: 0, int: 0},
      current_state: %CurrentState{
        hp: Keyword.get(opts, :hp, 100),
        sp: Keyword.get(opts, :sp, 10)
      },
      derived_stats: %DerivedStats{max_hp: 500, max_sp: 200, aspd: 150},
      modifiers: %{equipment: %{}, status_effects: %{}, job_bonuses: %{}, passive: %{}},
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
