defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.MonsterSummon168150 do
  @moduledoc """
  Trigger area that summons the final monster of the Crusader purification test.

  ## Behavior

  - Stays disabled until the test starts.
  - On first touch, summons the final monster and disables itself.
  - Opens the test exit when its death event fires.
  - Clears that monster when the test resets.

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
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster Summon#cr4")

  def on_event("OnTouch", ctx) do
    ctx
    |> summon_mob(
      mob_id: 1036,
      map: "job_cru",
      at: {168, 150},
      event: "Monster Summon#cr4-a::OnDead"
    )
    |> donpcevent("Monster Summon#cr4::OnEnd")
  end

  def on_event("OnDead", ctx), do: donpcevent(ctx, "Monster Summon#cr5::OnStart")
  def on_event("OnStart", ctx), do: enablenpc(ctx, "Monster Summon#cr4")
  def on_event("OnReset", ctx), do: killmonster(ctx, "job_cru", "Monster Summon#cr4-a::OnDead")
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Monster Summon#cr4")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
