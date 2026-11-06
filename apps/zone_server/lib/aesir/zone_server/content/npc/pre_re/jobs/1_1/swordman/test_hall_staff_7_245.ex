defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.TestHallStaff7245 do
  @moduledoc """
  Checks whether swordman test applicants want to surrender.

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
        x: 7,
        y: 245,
        dir: 0,
        sprite: 45,
        name: "Test Hall Staff",
        scope: :pre_renewal,
        unique_name: "Test Hall Staff#swd_4",
        trigger: {1, 3}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdteststaff
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = FJobswdteststaff.call(ctx, [10, 245])
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
