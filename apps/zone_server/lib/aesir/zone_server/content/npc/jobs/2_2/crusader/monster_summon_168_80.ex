defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.MonsterSummon16880 do
  @moduledoc """
  Trigger area that releases the second monster wave of the Crusader purification test.

  ## Behavior

  - Stays disabled until the test starts.
  - On first touch, summons the second wave and disables itself.

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
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster Summon#cr2")

  def on_event("OnTouch", ctx) do
    ctx
    |> donpcevent("Monster Summon#cr0::OnMonster2")
    |> donpcevent("Monster Summon#cr2::OnEnd")
  end

  def on_event("OnStart", ctx), do: enablenpc(ctx, "Monster Summon#cr2")
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Monster Summon#cr2")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
