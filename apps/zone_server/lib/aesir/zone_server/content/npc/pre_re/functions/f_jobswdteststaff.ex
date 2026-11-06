defmodule Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdteststaff do
  @moduledoc """
  Checks a swordman test applicant at an intermediate checkpoint.

  ## Behavior

  Offers the applicant one last chance to surrender: yes announces it on the test map and sends
  them back to Izlude, no lets them continue from the given position.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/swordman.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @test_map "job_sword1"

  @doc """
  Callable rAthena global function `F_JobSwdTestStaff(x, y)`; throws `{:script_end, ctx}`.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    ctx =
      ctx
      |> mes("[Test Hall Staff]")
      |> mes("Applicant #{char_name(ctx, 0)}. Do you surrender??")
      |> next()

    {ctx, choice} = select(ctx, ["Yes.", "No."])

    if choice == 1 do
      ctx =
        ctx
        |> mapannounce(@test_map, "Applicant #{char_name(ctx, 0)} quit the test..", 1)
        |> warp("izlude_in", 65, 165)

      throw({:script_end, ctx})
    else
      ctx = warp(ctx, @test_map, Enum.at(args, 0, 0), Enum.at(args, 1, 0))
      throw({:script_end, ctx})
    end
  end
end
