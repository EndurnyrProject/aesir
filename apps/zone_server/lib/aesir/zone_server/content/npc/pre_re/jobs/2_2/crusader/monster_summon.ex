defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M22.Crusader.MonsterSummon do
  @moduledoc """
  Returns purification applicants and resets the Crusader test events.

  ## Behavior

  - Starts disabled, can be enabled for the test, and resets the test controllers on touch.

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
        x: 168,
        y: 180,
        dir: 4,
        sprite: 45,
        name: "Monster Summon",
        scope: :pre_renewal,
        unique_name: "Monster Summon#cr5",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster Summon#cr5")

  def on_event("OnTouch_", ctx) do
    ctx
    |> warp("prt_castle", 35, 147)
    |> donpcevent("Monster Summon#cr0::OnReset")
    |> donpcevent("Monster Summon#cr4::OnReset")
    |> donpcevent("Monster Summon#cr0::OnEnd")
    |> donpcevent("Monster Summon#cr4::OnEnd")
    |> donpcevent("Monster Summon#cr5::OnEnd")
    |> donpcevent("Monster Summon#cr6::OnStop")
    |> donpcevent("Monster Summon#cr6::OnEnd")
    |> donpcevent("Waiting Room#cr1::OnStart")
  end

  def on_event("OnStart", ctx), do: enablenpc(ctx, "Monster Summon#cr5")
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Monster Summon#cr5")
end
