defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Dirt do
  @moduledoc """
  A patch of camp dirt where the rotting Nepenthes stem is planted during the Botanist's
  errand.

  ## Behavior

  - On `ep13_animal` step 8 plants the rotting stem and waters it, then sets the step to 9,
    consuming the Decaying Stem and granting a Germinating Sprout.
  - Does nothing on every other step.

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
        map: "mid_camp",
        x: 52,
        y: 148,
        dir: 1,
        sprite: 844,
        name: "Dirt",
        scope: :shared,
        unique_name: "Dirt#ep13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @decaying_stem 6035
  @germinating_sprout 7193

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_animal, 0) == 8 do
      plant_stem(ctx)
    else
      ctx
    end
  end

  defp plant_stem(ctx) do
    ctx
    |> mes("- You dug a hole into the ground, planted the rotting stem, and then watered it. -")
    |> next()
    |> mes("... ... ... ...")
    |> mes("... ... ... ...")
    |> next()
    |> mes("... ... ... ...")
    |> mes("... ... ... ...")
    |> mes("... ... ... ...")
    |> next()
    |> specialeffect(:lightsphere)
    |> mes("- Pzzzz -")
    |> mes("- Ssshuhhhh -")
    |> next()
    |> mes("- Something is growing out of the dirt. -")
    |> set_char_var(:ep13_animal, 9)
    |> delitem(@decaying_stem, 1)
    |> give_item(@germinating_sprout, 1)
    |> close()
  end
end
