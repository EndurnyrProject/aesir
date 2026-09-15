defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.RestingLaphine do
  @moduledoc """
  Comments on the wandering poet's arrival and music.

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
        x: 182,
        y: 213,
        dir: 1,
        sprite: 438,
        name: "Resting Laphine",
        scope: :shared,
        unique_name: "Resting Laphine#ep13_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[Resting Laphine]")
      |> mes("The poet on the stage is mysterious.")
      |> mes("The moment you came here...")
      |> mes("He arrived and started playing music.")
      |> next()
      |> mes("[Resting Laphine]")
      |> mes("This is music from your country yes?")
      |> mes("I think it sounds great.")
      |> close()
    else
      ctx
      |> mes("[Resting Laphine]")
      |> mes("IyazLarsSe Or An.")
      |> mes("marLoOsa Yee NeiBur")
      |> mes("Rinisehrnea Mu...? ")
      |> close()
    end
  end
end
