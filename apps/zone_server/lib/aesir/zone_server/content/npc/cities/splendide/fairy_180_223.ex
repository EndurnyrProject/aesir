defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy180223 do
  @moduledoc """
  Kalua judges the player's sophistication.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped; otherwise responds in untranslated language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "splendide",
        x: 180,
        y: 223,
        dir: 3,
        sprite: 440,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#ep13_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Kalua]")
      |> mes(
        "You don't look sophisticated, but I think you are better than those uncivilized guys who are around the snowfield."
      )
      |> close()
    else
      ctx
      |> mes("[Kalua]")
      |> mes(
        "AlahCyamah U MeKoser Ir TimaurRiveh Di LarsRasTi Di AgolKones Or AlahUdenAndu Ee FusRe"
      )
      |> close()
    end
  end
end
