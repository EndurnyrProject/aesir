defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy142315 do
  @moduledoc """
  A fairy boasts about flight and Laphine wings.

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
        x: 142,
        y: 315,
        dir: 3,
        sprite: 462,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#13_2_11"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Fairy]")
      |> mes("Flying in the sky is not easy.")
      |> mes("But it is better than a walk on the ground.")
      |> next()
      |> mes("[Fairy]")
      |> mes("Are you a human? Poor thing...")
      |> mes("You can't have these beautiful wings?")
      |> mes("Pathetic lives.")
      |> mes("It is obvious that we are the only ones who are blessed.")
      |> close()
    else
      ctx
      |> mes("[Fairy]")
      |> mes("WharemuLars Ur SharUdenWha Yu Agol")
      |> mes("LontasSar Ra DathVeAlah Ee Noh")
      |> mes("LarsLonnah Ko TalnesIman Ie Diel")
      |> next()
      |> mes("[Fairy]")
      |> mes("tasSarNuff Or WehFarDieb Ir FarRu")
      |> mes("FusYurnah So MeAshnar O Noth")
      |> mes("YurBurDu Yu VeldVaMush So Thor")
      |> mes("AgolDiebUor No TurnahAla O ")
      |> close()
    end
  end
end
