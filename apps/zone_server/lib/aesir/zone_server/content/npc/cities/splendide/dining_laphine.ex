defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.DiningLaphine do
  @moduledoc """
  Comments on fruit soup while dining in the Splendide camp.

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
        x: 161,
        y: 213,
        dir: 7,
        sprite: 447,
        name: "Dining Laphine",
        scope: :shared,
        unique_name: "Dining Laphine#ep13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[Dining Laphine]")
      |> mes("I got bored eating home cooked food.")
      |> mes("The only thing that keeps me coming here is fruit soup...")
      |> next()
      |> mes("[Dining Laphine]")
      |> mes("Hey you!")
      |> mes("Why are you staring at me eating dinner?")
      |> close()
    else
      ctx
      |> mes("[Dining Laphine]")
      |> mes("NothFarLu Ra...? ")
      |> mes("RuffYur..!")
      |> next()
      |> mes("- He is giving me a odd stare as he eats his dinner -")
      |> close()
    end
  end
end
