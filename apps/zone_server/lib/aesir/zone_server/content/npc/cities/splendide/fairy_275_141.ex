defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy275141 do
  @moduledoc """
  A fairy dismisses the player and proclaims her perfection.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped and the ep13_2_rhea gate is complete; otherwise
    responds in untranslated language.

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
        x: 275,
        y: 141,
        dir: 3,
        sprite: 447,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_7"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Don't talk to me. What do you want?")
      |> mes("I know you will blame something on me right?")
      |> next()
      |> mes("[Fairy]")
      |> mes("I don't want to listen to other people...")
      |> mes("I am perfect as I am!")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("narnahNoh Di WehRiniLars Yee ModAnu")
      |> mes("LuAlahNe Or FarAnduOsa No AgolKo")
      |> next()
      |> mes("[Fairy]")
      |> mes("LarsVilDim No WhaVilFus Ha Ash")
      |> mes("ReLarsShar Mu AnduLoLon Ie Nufftas")
      |> close()
    end
  end
end
