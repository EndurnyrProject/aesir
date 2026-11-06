defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M22.Crusader.Summoner do
  @moduledoc """
  Returns a successful endurance applicant to the Crusader examiner.

  ## Behavior

  - Advances the endurance quest before returning the applicant.

  ## Credits

  - Original from rAthena; no author is named for this NPC in the source.

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/2-2/crusader.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "job_cru",
        x: 98,
        y: 105,
        dir: 4,
        sprite: 45,
        name: " Summoner",
        scope: :pre_renewal,
        unique_name: " Summoner#cr5",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> set_char_var(:CRUS_Q, 6)
    |> changequest(3010, 3011)
    |> warp("prt_castle", 164, 28)
  end
end
