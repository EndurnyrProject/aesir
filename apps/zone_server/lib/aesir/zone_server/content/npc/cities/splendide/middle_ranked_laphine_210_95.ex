defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.MiddleRankedLaphine21095 do
  @moduledoc """
  Cheers while reacting to something impressive.

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
        x: 210,
        y: 95,
        dir: 3,
        sprite: 442,
        name: "Middle-Ranked Laphine",
        scope: :shared,
        unique_name: "Middle-Ranked Laphine#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx |> mes("[Middle-Ranked Laphine]") |> mes("Wow~ Great!!") |> emotion(:best) |> close()
    else
      ctx
      |> mes("[Middle-Ranked Laphine]")
      |> mes("MushIyazTur Ee YurDana")
      |> emotion(:best)
      |> close()
    end
  end
end
