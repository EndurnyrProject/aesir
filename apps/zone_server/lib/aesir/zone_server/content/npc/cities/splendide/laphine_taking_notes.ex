defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.LaphineTakingNotes do
  @moduledoc """
  Discusses studying the wandering poet's unfamiliar music.

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
        x: 162,
        y: 202,
        dir: 5,
        sprite: 436,
        name: "Laphine taking notes",
        scope: :shared,
        unique_name: "Laphine taking notes#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[Laphine taking notes]")
      |> mes("We are quite impressed by the poet.")
      |> mes("We Laphine love music as well.")
      |> mes("I never imagined that I would ever hear such exotic music.")
      |> next()
      |> mes("[Laphine taking notes]")
      |> mes("I want to study music someday.")
      |> mes("I plan to write much about the study of instruments and music")
      |> next()
      |> mes("[Laphine taking notes]")
      |> mes("Someday you should listen to mu people's music.")
      |> close()
    else
      ctx
      |> mes("[Laphine taking notes]")
      |> mes("TiTalLars Ur tasThorNoth O AnImanWha.")
      |> mes("FusLuRuff..... Mu TingLuAla Yee AnmanAndu")
      |> next()
      |> mes("- He seems frustrated that you don't understand him -")
      |> close()
    end
  end
end
