defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.TestHallStaff230242 do
  @moduledoc """
  Offers swordman test applicants a chance to surrender.

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
        x: 230,
        y: 242,
        dir: 2,
        sprite: 105,
        name: "Test Hall Staff",
        scope: :pre_renewal,
        unique_name: "Test Hall Staff#swd_2"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdstaff
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = FJobswdstaff.call(ctx, [1])
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
