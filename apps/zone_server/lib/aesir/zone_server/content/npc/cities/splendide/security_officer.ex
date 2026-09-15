defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.SecurityOfficer do
  @moduledoc """
  Warns visitors about Splendide's underground prison.

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
        x: 190,
        y: 314,
        dir: 5,
        sprite: 461,
        name: "Security Officer",
        scope: :shared,
        unique_name: "Security Officer#tre"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Security Officer]")
      |> mes("This is the underground prison of Splendide.")
      |> mes("Those who are guilty and prisoners are detained here.")
      |> next()
      |> mes("[Security Officer]")
      |> mes(
        "If you do something suspicious, you must be detained here too, so you'd better to be careful!"
      )
      |> close()
    else
      ctx
      |> mes("[Security Officer]")
      |> mes("GothremuAman Ha DimDielNuff")
      |> mes("GothAnAsh er NohVaAgol Yee CyaOsaDor U Aman U ")
      |> mes("TurOdesVrum Ir TalDathOsa Ie WosAgolVrum Ha neaNudHir Ha SeAnVil Di narAlahLars Yu")
      |> close()
    end
  end
end
