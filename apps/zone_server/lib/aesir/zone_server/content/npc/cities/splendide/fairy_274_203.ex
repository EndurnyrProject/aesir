defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy274203 do
  @moduledoc """
  A fairy asks the player about the human world.

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
        x: 274,
        y: 203,
        dir: 3,
        sprite: 444,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Hey, you~! Human! How did you find us?")
      |> mes("What does your human world look like?")
      |> mes("Is it fun to be there?")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("AnnarNor So marFarAno Di NudThusNei Ir Ir ")
      |> mes("narVaTi Mu SharDimmaur Or Ano")
      |> mes("WhaModKo Or eoNeiNor Di ImanDunah O O ")
      |> close()
    end
  end
end
