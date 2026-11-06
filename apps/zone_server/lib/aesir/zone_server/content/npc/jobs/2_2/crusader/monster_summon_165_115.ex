defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.MonsterSummon165115 do
  @moduledoc """
  Trigger area that releases the third monster wave of the Crusader purification test.

  ## Behavior

  - Stays disabled until the test starts.
  - On first touch, summons the third wave and disables itself.

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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_cru",
        x: 165,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "Monster Summon",
        scope: :shared,
        unique_name: "Monster Summon#cr3",
        trigger: {15, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster Summon#cr3")

  def on_event("OnTouch_", ctx) do
    ctx
    |> donpcevent("Monster Summon#cr0::OnMonster3")
    |> donpcevent("Monster Summon#cr3::OnEnd")
  end

  def on_event("OnStart", ctx), do: enablenpc(ctx, "Monster Summon#cr3")
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Monster Summon#cr3")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
