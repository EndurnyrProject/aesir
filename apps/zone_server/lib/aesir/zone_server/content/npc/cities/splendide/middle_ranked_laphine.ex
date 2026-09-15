defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.MiddleRankedLaphine do
  @moduledoc """
  Demonstrates a bright magical effect.

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
        x: 207,
        y: 97,
        dir: 5,
        sprite: 443,
        name: "Middle-Ranked Laphine",
        scope: :shared,
        unique_name: "Middle-Ranked Laphine#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Middle-Ranked Laphine]")
      |> mes("Haap-!")
      |> mes("See? Same as a streetlight, right?")
      |> specialeffect(:level99_4)
      |> close()
    else
      ctx
      |> mes("[Middle-Ranked Laphine]")
      |> mes("sehrVa")
      |> mes("IyazAnman Di TurHirCya")
      |> specialeffect(:level99_4)
      |> close()
    end
  end
end
