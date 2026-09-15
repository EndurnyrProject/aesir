defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.SplendideGuard do
  @moduledoc """
  Warns visitors to remain quiet around the prisoners.

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
        x: 281,
        y: 329,
        dir: 3,
        sprite: 447,
        name: "Splendide Guard",
        scope: :shared,
        unique_name: "Splendide Guard#tre"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Splendide Guard]")
      |> mes(
        "If you make too much noise, the prisoners will cause trouble. So try to keep quiet at all times."
      )
      |> close()
    else
      ctx
      |> mes("[Splendide Guard]")
      |> mes("AnduVeldRe Ko VeldReFulo So LomaurDu So\tSo ")
      |> close()
    end
  end
end
