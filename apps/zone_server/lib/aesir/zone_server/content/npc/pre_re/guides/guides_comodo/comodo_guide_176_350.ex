defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesComodo.ComodoGuide176350 do
  @moduledoc """
  Comodo guide, speaking as Native Nutcoco, who directs visitors to the city's facilities.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - MasterOfMuppets

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "comodo",
        x: 176,
        y: 350,
        dir: 4,
        sprite: 700,
        name: "Comodo Guide",
        scope: :pre_renewal,
        unique_name: "Comodo Guide#2cmd"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FCmdguide
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = FCmdguide.call(ctx, ["Native Nutcoco"])
    ctx
  end
end
