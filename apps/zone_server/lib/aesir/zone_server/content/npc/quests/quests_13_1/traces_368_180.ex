defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Traces368180 do
  @moduledoc """
  A carved mark under a small tree on the Huwaei field, read during the search for Rayan
  Moore.

  ## Behavior

  - During steps 7 and 8 of the search reads the weathered arrow pointing southwest.
  - Otherwise finds scribbling the player cannot decipher.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_fild04",
        x: 368,
        y: 180,
        dir: 0,
        sprite: 844,
        name: "Traces",
        scope: :shared,
        unique_name: "Traces#mao2_object03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) in [7, 8] do
      arrow(ctx)
    else
      unreadable(ctx)
    end
  end

  defp arrow(ctx) do
    ctx
    |> mes("Somebody left a mark under this small tree.")
    |> mes("The mark is weathered and faded,")
    |> mes("but it is an arrow pointing southwest.")
    |> close()
  end

  defp unreadable(ctx) do
    ctx
    |> mes("There's some scribbling on the tree,")
    |> mes("but you can't decipher what it means.")
    |> close()
  end
end
