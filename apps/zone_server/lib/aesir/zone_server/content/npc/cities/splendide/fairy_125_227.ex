defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy125227 do
  @moduledoc """
  Flowa comments on the player's heavy human body.

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
        x: 125,
        y: 227,
        dir: 3,
        sprite: 444,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#ep13_3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Flowa]")
      |> mes("No offense, I was not looking at you with sympathy.")
      |> mes("I just wondered how you could walk with that heavy body...")
      |> close()
    else
      ctx
      |> mes("[Flowa]")
      |> mes("AnuFuloUor Ko CyaWosnes Ha WosAnuAsh O WosDuAno O ")
      |> mes("FuloAndueo Ie WosGothLars Ee Tinarmaur Or AlahnahVa Or narAnuFulo So KoCya")
      |> close()
    end
  end
end
