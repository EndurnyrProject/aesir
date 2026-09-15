defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy22954 do
  @moduledoc """
  A fairy questions how the player reached Splendide.

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
        x: 229,
        y: 54,
        dir: 3,
        sprite: 439,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Huh? You are a human.")
      |> mes(
        "You are better than those fat Saphas, but still you are not a beautiful thing also."
      )
      |> next()
      |> mes("[Fairy]")
      |> mes("How did you find this wonderful place?")
      |> mes("This is a sophisticated place.")
      |> mes("I don't think you can be here with us.")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("ImanAnuUor Yee NeUorVer Ir RivehAshOsa")
      |> mes("AdorserHir er OsaAlahAno Mu RivehDath")
      |> next()
      |> mes("[Fairy]")
      |> mes("LarsFuloSar Yu VilGotheor Yu nes")
      |> mes("Anuneseor Ie remuSeDieb er ")
      |> mes("WosLoNud Ko NuffDuIman Ir ")
      |> close()
    end
  end
end
