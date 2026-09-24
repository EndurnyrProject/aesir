defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.MonsterSummon16845 do
  @moduledoc """
  Trigger area that releases the first monster wave of the Crusader purification test.

  ## Behavior

  - Stays disabled until the test starts.
  - On first touch, summons the first wave and disables itself.

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
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster Summon#cr1")

  def on_event("OnTouch", ctx) do
    ctx
    |> donpcevent("Monster Summon#cr0::OnMonster1")
    |> donpcevent("Monster Summon#cr1::OnEnd")
  end

  def on_event("OnStart", ctx), do: enablenpc(ctx, "Monster Summon#cr1")
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Monster Summon#cr1")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
