defmodule Aesir.ZoneServer.Content.Npc.Cities.Izlude.Sailor do
  @moduledoc """
  Offers travelers passage from Byalan Island back to Izlude.

  ## Behavior

  - Lets the player return to Izlude or remain on Byalan Island.
  - Uses mode-specific arrival coordinates in Izlude.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlu2dun",
        x: 108,
        y: 27,
        dir: 0,
        sprite: 100,
        name: "Sailor",
        scope: :shared,
        unique_name: "Sailor#2izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sailor]")
      |> mes("Wanna")
      |> mes("head back?")
      |> next()
      |> select(["Yeah, I'm tired to death.", "Nope, I love this place!"])

    if choice == 1 do
      if Rathena.truthy?(checkre(ctx, 0)) do
        warp(ctx, "izlude", 197, 210)
      else
        warp(ctx, "izlude", 176, 182)
      end
    else
      close(ctx)
    end
  end
end
