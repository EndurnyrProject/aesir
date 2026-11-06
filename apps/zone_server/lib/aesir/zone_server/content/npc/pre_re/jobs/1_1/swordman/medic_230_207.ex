defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.Medic230207 do
  @moduledoc """
  Heals applicants at the second swordman test checkpoint.

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
        y: 207,
        dir: 2,
        sprite: 105,
        name: "Medic",
        scope: :pre_renewal,
        unique_name: "Medic#2swd_2"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdmedic
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = FJobswdmedic.call(ctx, ["2nd"])
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
