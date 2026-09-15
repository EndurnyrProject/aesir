defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.Fairy163264 do
  @moduledoc """
  A fairy boasts about her beauty.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped; otherwise responds in untranslated language.

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
        x: 163,
        y: 264,
        dir: 3,
        sprite: 438,
        name: "Fairy",
        scope: :shared,
        unique_name: "Fairy#ep13bs2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Fairy]")
      |> mes("What are you looking at!")
      |> next()
      |> mes("[Fairy]")
      |> mes("Oh me! You know beauty when you see it don't you~?!")
      |> close()
    else
      ctx
      |> mes("[nes]")
      |> mes("UorVeLars No Ador")
      |> next()
      |> mes("[nes]")
      |> mes("SeGothShar An AshDur")
      |> close()
    end
  end
end
