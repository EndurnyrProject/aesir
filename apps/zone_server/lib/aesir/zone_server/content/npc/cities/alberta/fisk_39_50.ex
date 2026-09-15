defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Fisk3950 do
  @moduledoc """
  Offers passage from the Sunken Ship area back to Alberta.

  ## Behavior

  - Warps consenting visitors to Alberta at no charge.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alb2trea",
        x: 39,
        y: 50,
        dir: 6,
        sprite: 100,
        name: "Fisk",
        scope: :shared,
        unique_name: "Fisk#a2t"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Fisk]")
      |> mes("So you wanna head back to the mainland in Alberta, eh?")
      |> next()
      |> select(["Yes please.", "I changed my mind."])

    ctx = if choice == 1, do: warp(ctx, "alberta", 192, 169), else: ctx
    close(ctx)
  end
end
