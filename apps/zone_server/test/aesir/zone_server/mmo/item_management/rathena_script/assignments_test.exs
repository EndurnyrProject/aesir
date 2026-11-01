defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.AssignmentsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  test "a local assignment rolls once and branch updates reach subsequent statements" do
    script = ".@rnd = rand(1,10); if (.@rnd > 0) .@rnd += 1; .@copy = .@rnd;"

    assert {:ok, source} = Transpiler.transpile(script)
    assert length(Regex.scan(~r/Enum\.random/, source)) == 1

    result = evaluate(source)
    assert result.vars.rnd in 2..11
    assert result.vars.copy == result.vars.rnd
  end

  test "Zeny assignments, including increments, use the balance parameter setter" do
    for {script, value} <- [
          {"Zeny++;", "(zeny(ctx) + 1)"},
          {"Zeny -= 5;", "(zeny(ctx) - 5)"},
          {"Zeny += rand(1000,10000);", "(zeny(ctx) + Enum.random(1000..10000))"}
        ] do
      assert Transpiler.transpile(script) == {:ok, "set_zeny(ctx, #{value})"}
    end
  end

  test "unset locals read as zero and end stops subsequent statements" do
    script = ".@value = 7; if (.@missing == 0) end; .@value = 99;"

    assert {:ok, source} = Transpiler.transpile(script)
    assert evaluate(source).vars == %{value: 7}
  end

  defp evaluate(source) do
    quoted =
      quote do
        import Dsl
        unquote(Code.string_to_quoted!(source))
      end

    ctx = %Ctx{
      char_id: nil,
      account_id: nil,
      connection_pid: nil,
      game_state: nil,
      source: {:item, 1}
    }

    {result, _binding} = Code.eval_quoted(quoted, ctx: ctx)
    result
  catch
    :throw, {:script_end, %Ctx{} = ended} -> ended
  end
end
