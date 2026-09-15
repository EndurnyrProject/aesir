defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.SplendideSoldier20176 do
  @moduledoc """
  Identifies Splendide as the Laphine garrison base.

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
        x: 201,
        y: 76,
        dir: 3,
        sprite: 461,
        name: "Splendide Soldier",
        scope: :shared,
        unique_name: "Splendide Soldier#tre2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Splendide Soldier]")
      |> mes("This is Splendide, the garrison base of the Laphine.")
      |> close()
    else
      ctx
      |> mes("[Splendide Soldier]")
      |> mes("SeAshLu Di YurDiebTing Ee VeModTur No NuffLarsVa No ")
      |> close()
    end
  end
end
