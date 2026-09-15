defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy159164 do
  @moduledoc """
  A fairy complains about fighting the Saphas.

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
        x: 159,
        y: 164,
        dir: 3,
        sprite: 461,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("It is shame that I have to")
      |> mes("cope with those fat beasts.")
      |> mes("I am just too delicate to fight with them.")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("RiniHirDieb Ie nahImanMe Di Mush")
      |> mes("mahnarAsh So HirAnMod O Ras")
      |> mes("neaLoDath Ha KoRivehWha So Thusnea")
      |> close()
    end
  end
end
