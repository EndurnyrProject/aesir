defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesComodo.ComodoGuide do
  @moduledoc """
  Comodo guide, speaking as Native Kokomo, who directs visitors to the city's facilities.

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
        x: 322,
        y: 178,
        dir: 4,
        sprite: 700,
        name: "Comodo Guide",
        scope: :pre_renewal,
        unique_name: "CmdGuide"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.PreRe.Functions.FCmdguide
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = FCmdguide.call(ctx, ["Native Kokomo"])
    ctx
  end
end
