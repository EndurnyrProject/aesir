defmodule Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdteststaff2 do
  @moduledoc """
  Announces that an applicant passed a swordman test course and moves them on.

  ## Behavior

  Announces the cleared course on the test map and warps the applicant to the next position.

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
  Callable rAthena global function `F_JobSwdTestStaff2(course, x, y)`; throws `{:script_end, ctx}`.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    course = Enum.at(args, 0, 0)

    ctx =
      ctx
      |> mapannounce(
        @test_map,
        "Applicant #{char_name(ctx, 0)}. Pass the #{course} course.",
        1
      )
      |> warp(@test_map, Enum.at(args, 1, 0), Enum.at(args, 2, 0))

    throw({:script_end, ctx})
  end
end
