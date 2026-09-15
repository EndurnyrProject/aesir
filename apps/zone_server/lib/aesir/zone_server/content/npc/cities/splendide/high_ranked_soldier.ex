defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.HighRankedSoldier do
  @moduledoc """
  Discusses newly arrived swords with another Laphine soldier.

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
        map: "spl_in01",
        x: 122,
        y: 314,
        dir: 5,
        sprite: 461,
        name: "High-Ranked Soldier",
        scope: :shared,
        unique_name: "High-Ranked Soldier#ep13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[High-Ranked Soldier]")
      |> mes("Are there any new supplies?")
      |> next()
      |> mes("[Laphine Soldier]")
      |> mes("This sword just arrived...")
      |> mes(
        "This is inspired by stars, and we tested it by cutting the thread floating over the water."
      )
      |> next()
      |> mes("[High-Ranked Soldier]")
      |> mes("Hmm, we rarely used swords. But it looks great as a decoration.")
      |> next()
      |> mes("- Seems their busy talking about weapons -")
      |> close()
    else
      ctx
      |> mes("[High-Ranked Soldier]")
      |> mes("NorVerNuff Ee Re....")
      |> next()
      |> mes("[Laphine Soldier]")
      |> mes("FusVerAlah Di ")
      |> mes("ModNorNor U DimVohlWeh O DimAmannea An WosAnoNoh An AnduMeOdes So TalAdor.")
      |> next()
      |> mes("[High-Ranked Soldier]")
      |> mes("DurNohHir Ha UorVaThus Di AshNuffLon U mahNuffThus U RuAmanAgol Ir NohHir...?")
      |> close()
    end
  end
end
