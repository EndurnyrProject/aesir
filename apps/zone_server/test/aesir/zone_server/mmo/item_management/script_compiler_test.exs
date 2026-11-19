defmodule Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompilerTest do
  # compile_all!/1 redefines the global CompiledItemScripts module.
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.ZoneServer.Factory
  import ExUnit.CaptureIO

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Script.Ctx

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(StatusInterpreter, :apply_status_with_events, fn _, _, _, _ -> {:ok, []} end)
    stub(StatusInterpreter, :remove_status_with_events, fn _, _, _, _ -> {:ok, []} end)

    :ok
  end

  test "compile_all!/1 returns :ok and a compiled healing script raises hp" do
    assert ScriptCompiler.compile_all!([item_def(501, "heal(ctx, hp: 50)")]) == :ok

    ctx = CompiledItemScripts.on_use(501, build_ctx(hp: 100))

    assert ctx.status == :ok
    assert ctx.game_state.stats.current_state.hp == 150
  end

  test "compiled classification follows the standalone staged source and staging changes only effects" do
    source = "ItemDialogs.stage(ctx, :cash_city, [5])"

    assert :ok =
             ScriptCompiler.compile_all!([
               item_def(12_510, source),
               item_def(501, "heal(ctx, hp: 50)")
             ])

    assert CompiledItemScripts.interactive?(12_510)
    refute CompiledItemScripts.interactive?(501)
    refute CompiledItemScripts.interactive?(999_999)
    ctx = build_ctx()
    staged = CompiledItemScripts.on_use(12_510, ctx)
    assert staged.session_effects == [{:item_dialog, :cash_city, [5]}]
    assert %{staged | session_effects: []} == ctx

    assert :ok = ScriptCompiler.compile_all!([item_def(12_510, "ctx")])
    refute CompiledItemScripts.interactive?(12_510)
  end

  test "invalid or embedded staging calls fail compilation instead of entering the inline path" do
    for source <- [
          "ItemDialogs.stage(ctx, :cash_city, [6])",
          "ItemDialogs.stage(ctx, :unknown, [])",
          "ItemDialogs.stage(ctx, :cash_city, [base_level(ctx)])",
          "ctx = heal(ctx, hp: 10); ItemDialogs.stage(ctx, :cash_city, [1])",
          "if true do ItemDialogs.stage(ctx, :cash_city, [1]) else ctx end"
        ] do
      assert_raise ArgumentError, ~r/item.dialog/, fn ->
        ScriptCompiler.compile_all!([item_def(12_510, source)])
      end
    end
  end

  test "a Homunculus item script stages its typed effect" do
    assert ScriptCompiler.compile_all!([item_def(12_040, "homevolution(ctx)")]) == :ok

    assert %Ctx{session_effects: [{:homunculus, :homunculus_evolution}]} =
             CompiledItemScripts.on_use(12_040, build_ctx())
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

    expect(StatusInterpreter, :apply_status_with_events, fn :player, 1, :sc_blessing, params ->
      send(test_pid, {:applied, params})
      {:ok, [{:sc_blessing, :apply}]}
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

  defp item_def(id, on_use), do: build(:item_definition, id: id, on_use: on_use)

  defp build_ctx(opts \\ []) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state:
        build(:player_state,
          character_id: 1,
          account_id: 100,
          sex: "M",
          inventory: %{},
          stats: %{
            base_stats: %{vit: 0, int: 0},
            current_state: %{hp: Keyword.get(opts, :hp, 100), sp: 10},
            derived_stats: %{max_hp: 500, max_sp: 200, aspd: 150},
            progression: %{base_level: 10, job_level: 3, job_id: 0}
          }
        ),
      source: {:item, 501}
    }
  end
end
