defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy do
  @moduledoc """
  An exhausted fairy reacts to the player approaching.

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
        x: 218,
        y: 193,
        dir: 3,
        sprite: 441,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#ep13_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Exhausted Fairy]")
      |> mes("Wait, don't come any closer. I can't stand your smell, it makes me feel dizzy.")
      |> close()
    else
      ctx
      |> mes("[Exhausted Fairy]")
      |> mes(
        "OdesKoUor Ko NuffSharUden Ko CyaVenah An NudNuffser An KoRivehAdor Mu LarseorAnu O DorNe"
      )
      |> close()
    end
  end
end
