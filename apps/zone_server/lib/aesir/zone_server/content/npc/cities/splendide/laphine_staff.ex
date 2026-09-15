defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.LaphineStaff do
  @moduledoc """
  Refuses to sell scarce food to strangers in the Splendide camp.

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
        x: 189,
        y: 207,
        dir: 3,
        sprite: 439,
        name: "Laphine Staff",
        scope: :shared,
        unique_name: "Laphine Staff#ep13_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[Laphine Staff]")
      |> mes("Hm, what's up?")
      |> mes("I'm sorry, but we don't sell food to strangers.")
      |> next()
      |> mes("[Laphine Staff]")
      |> mes("You guys also need to be careful of food here.")
      |> mes("Food is scarce here.")
      |> next()
      |> mes("[Laphine Staff]")
      |> mes("You're going to have to find food somewhere else.")
      |> close()
    else
      ctx
      |> mes("[Laphine Staff]")
      |> mes("VeldAnoWeh Or ")
      |> mes("TurWos")
      |> mes("......ah...")
      |> next()
      |> mes(
        "- You just grin and smile. It's frustrating not to be able to understand their language. -"
      )
      |> close()
    end
  end
end
