defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.LaphineSoldier122311 do
  @moduledoc """
  Discusses the military storage and its delicate swords.

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
        y: 311,
        dir: 1,
        sprite: 447,
        name: "Laphine Soldier",
        scope: :shared,
        unique_name: "Laphine Soldier#ep13_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[Laphine Soldier]")
      |> mes("Are you a stranger?")
      |> mes("Have you come here to see the Laphine's military storage?")
      |> next()
      |> mes("[High-Ranked Soldier]")
      |> mes("Nevermind. These are useless to them...")
      |> mes("How can this delicate sword be used by those brutes...?")
      |> next()
      |> mes("[Laphine Soldier]")
      |> mes("O")
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
