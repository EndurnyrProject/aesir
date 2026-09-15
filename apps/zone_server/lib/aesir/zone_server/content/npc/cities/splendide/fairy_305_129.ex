defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy305129 do
  @moduledoc """
  A bored fairy considers makeup and beauty sleep instead of fighting.

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
        x: 305,
        y: 129,
        dir: 3,
        sprite: 436,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_10"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Hu...feel sleepy.")
      |> mes("I am so bored. I have nothing to do.")
      |> mes(
        "Even my friends are fighting with those giants, but it is not really my job to help them."
      )
      |> next()
      |> mes("[Fairy]")
      |> mes("I better check my make-up")
      |> mes("in the dressing room.")
      |> mes("Or should I get more beauty sleep?")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("AnduNothUor O eomaurShar Mu AnduVeld")
      |> mes("AdorFulotas Ko NorAlahAsh Ie Ala")
      |> mes("KoOsaLon Ha AnuNeiNoh Di Ting")
      |> mes("tasKoDiel O IyazGoth")
      |> next()
      |> mes("[Fairy]")
      |> mes("OdesmahHir Or mahneaLars So ")
      |> mes("HirNudAman O AdorWosDu")
      |> mes("DimYurVa So DanaRuYur")
      |> close()
    end
  end
end
