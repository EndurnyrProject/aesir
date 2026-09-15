defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.RestingLaphine181218 do
  @moduledoc """
  Listens to the wandering poet and asks about his music.

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
        x: 181,
        y: 218,
        dir: 5,
        sprite: 446,
        name: "Resting Laphine",
        scope: :shared,
        unique_name: "Resting Laphine#ep13_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("- He is nodding his head to the sound of the music -")
      |> next()
      |> mes("[Resting Laphine]")
      |> mes("Do you know how to play a similar sound?")
      |> mes("This tone is unbelievable.")
      |> close()
    else
      ctx
      |> mes("- He is nodding his head to the sound of the music -")
      |> next()
      |> mes("[Resting Laphine]")
      |> mes("GothTingNoth Di~ nar..")
      |> mes("DiebIyazNud Yu FarAn")
      |> mes("nesFarDor U ~")
      |> close()
    end
  end
end
