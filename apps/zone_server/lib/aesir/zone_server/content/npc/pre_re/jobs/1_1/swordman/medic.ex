defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.Medic do
  @moduledoc """
  Heals applicants at the first swordman test checkpoint.

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
        y: 245,
        dir: 2,
        sprite: 105,
        name: "Medic",
        scope: :pre_renewal,
        unique_name: "Medic#swd_1"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FJobswdmedic
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = FJobswdmedic.call(ctx, ["1st"])
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
