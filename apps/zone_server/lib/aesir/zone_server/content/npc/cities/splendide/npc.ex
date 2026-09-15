defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Npc do
  @moduledoc """
  A wounded Manuk prisoner pleads for an injection.

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
        x: 287,
        y: 306,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#spl_prs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Manuk Prisoner]")
      |> mes("My, my body...!!")
      |> mes("Injection! Please!! Help me!")
      |> close()
    else
      ctx
      |> mes("[Manuk Prisoner]")
      |> mes("Gi ha sd I das ")
      |> mes("Yda sod ja si dsa")
      |> close()
    end
  end
end
