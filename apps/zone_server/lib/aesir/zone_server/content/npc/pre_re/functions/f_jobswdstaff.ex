defmodule Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdstaff do
  @moduledoc """
  Offers a swordman test applicant the chance to surrender.

  ## Behavior

  Surrendering announces it on the test map and returns the applicant to Izlude; refusing
  encourages them and closes the dialog.

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

  @doc "Callable rAthena global function `F_JobSwdStaff`; throws `{:script_end, ctx}`."
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, _args) do
    ctx = ctx |> mes("[Test Hall Staff]") |> mes("Do you surrender?") |> next()
    {ctx, choice} = select(ctx, ["Yes.", "No."])

    if choice == 1 do
      ctx =
        ctx
        |> mapannounce(@test_map, "Applicant #{char_name(ctx, 0)} quit the test.", 1)
        |> warp("izlude_in", 65, 165)

      throw({:script_end, ctx})
    else
      ctx = ctx |> mes("[Test Hall Staff]") |> mes("Bravo! Go for it again!") |> close()
      throw({:script_end, ctx})
    end
  end
end
