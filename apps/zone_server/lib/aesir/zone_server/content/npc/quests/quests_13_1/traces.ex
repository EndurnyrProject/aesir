defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Traces do
  @moduledoc """
  Battle traces on the Huwaei field, followed during the search for Rayan Moore.

  ## Behavior

  - During steps 7 and 8 of the search describes the recent battle and the blood on the ground.
  - Otherwise only mentions the footprints.

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
        x: 321,
        y: 131,
        dir: 0,
        sprite: 844,
        name: "Traces",
        scope: :shared,
        unique_name: "Traces#mao2_object02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) in [7, 8] do
      battle_site(ctx)
    else
      footprints(ctx)
    end
  end

  defp battle_site(ctx) do
    ctx
    |> mes("You find many footprints on the ground.")
    |> mes(
      "Considering all the blood on the ground, a battle must have occurred here fairly recently."
    )
    |> mes("The footprints continue over the hill.")
    |> close()
  end

  defp footprints(ctx) do
    ctx
    |> mes("You found some footprints.")
    |> close()
  end
end
