defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy181107 do
  @moduledoc """
  A fairy boasts about Laphine cleanliness.

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
        x: 181,
        y: 107,
        dir: 5,
        sprite: 462,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_12"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Neatness, tidiness and cleanness!")
      |> mes("Those are the words.")
      |> mes("that can describe us!")
      |> mes("Others are so dirty and messy!")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("FusYurnah So M ")
      |> mes("WehFarDieb Ir FarRu ")
      |> mes("FusYurnah ")
      |> mes("AgolDiebUor No Tur")
      |> close()
    end
  end
end
