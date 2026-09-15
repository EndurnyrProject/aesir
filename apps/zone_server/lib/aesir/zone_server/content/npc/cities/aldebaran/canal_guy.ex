defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.CanalGuy do
  @moduledoc """
  Explains Al De Baran’s decorative canal system.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 46,
        y: 129,
        dir: 4,
        sprite: 97,
        name: "Canal Guy",
        scope: :shared,
        unique_name: "Canal Guy#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Panama]")
      |> mes(
        "Al De Baran is known world wide as the City of Canals. The waterways really add a sophisticated, romantic touch to our fair city."
      )
      |> next()
      |> select(["About the Canals", "End Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Panama]")
        |> mes("Well, a canal is an artificial waterway used for travel,")
        |> mes("shipping, or irrigation.")
        |> next()
        |> mes("[Panama]")
        |> mes(
          "However, the canals over here are just for show. If we needed to transport anything, we just use the Kafra Corporation Teleport service!"
        )
        |> close()

      2 ->
        ctx
        |> mes("[Panama]")
        |> mes("I have that you will enjoy your stay in Al De Baran.")
        |> close()

      _ ->
        ctx
    end
  end
end
