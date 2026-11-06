defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.MonsterSummon0 do
  @moduledoc """
  Opens the Crusader purification test exit when the final summoned monster dies.

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
        x: 168,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "Monster Summon",
        scope: :shared,
        unique_name: "Monster Summon#cr4-a"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnDead", ctx), do: donpcevent(ctx, "Monster Summon#cr5::OnStart")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
