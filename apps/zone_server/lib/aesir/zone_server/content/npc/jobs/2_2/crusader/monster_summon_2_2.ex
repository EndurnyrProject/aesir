defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.MonsterSummon22 do
  @moduledoc """
  Time limit controller for the Crusader purification test.

  ## Behavior

  - Starts a timer when the test begins.
  - After the time runs out, warps everyone out of the arena, clears the remaining
    monsters, disables the test stages, and reopens the waiting room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - Kisuka
    - Capuche
    - Komurka
    - massdriller
    - DracoRPG
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer241000", ctx) do
    ctx
    |> areawarp("job_cru", 160, 14, 175, 178, "job_cru", 24, 169)
    |> donpcevent("Monster Summon#cr0::OnReset")
    |> donpcevent("Monster Summon#cr4::OnReset")
    |> donpcevent("Monster Summon#cr0::OnEnd")
    |> donpcevent("Monster Summon#cr4::OnEnd")
    |> donpcevent("Monster Summon#cr5::OnEnd")
    |> donpcevent("Monster Summon#cr6::OnStop")
    |> donpcevent("Monster Summon#cr6::OnEnd")
    |> donpcevent("Waiting Room#cr1::OnStart")
  end

  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster Summon#cr6")
  def on_event("OnStart", ctx), do: ctx |> enablenpc("Monster Summon#cr6") |> initnpctimer()
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Monster Summon#cr6")
  def on_event("OnStop", ctx), do: stopnpctimer(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
