defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.TestHallStaff192244 do
  @moduledoc """
  Announces a completed swordman test course and moves the applicant onward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/swordman.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "job_sword1",
        x: 192,
        y: 244,
        dir: 0,
        sprite: 45,
        name: "Test Hall Staff",
        scope: :pre_renewal,
        unique_name: "Test Hall Staff#swd_7",
        trigger: {1, 3}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdteststaff2
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} =
      FJobswdteststaff2.call(ctx, ["1st", 215, 244])

    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
