defmodule Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdmedic do
  @moduledoc """
  Heals the applicant at a swordman test checkpoint.

  ## Behavior

  Restores all HP and names the check point the applicant just reached, then closes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/swordman.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `F_JobSwdMedic(course)`; throws `{:script_end, ctx}`.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    ctx =
      ctx
      |> percent_heal(hp: 100, sp: 0)
      |> mes("[Medic]")
      |> mes("This is the #{Enum.at(args, 0, 0)} check point! Cheer up!")
      |> close()

    throw({:script_end, ctx})
  end
end
