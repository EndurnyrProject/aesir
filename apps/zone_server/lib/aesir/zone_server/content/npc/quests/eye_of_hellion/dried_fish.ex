defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.DriedFish do
  @moduledoc """
  The Payon dried fish stall that carries the fifth Eye of Hellion clue.

  ## Behavior

  - While `HELLIONQ` is 50, quotes the `Green Herbs are very useful for getting
    rid of fish smells` message and advances `HELLIONQ` to 51.
  - Says nothing at any other quest step.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 239,
        y: 56,
        dir: 3,
        sprite: 111,
        name: "Dried Fish",
        scope: :shared,
        unique_name: "Dried Fish#paypuzz3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :HELLIONQ, 0) == 50 do
      read_message(ctx)
    else
      ctx
    end
  end

  defp read_message(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("So... Dried fish all")
    |> mes("around me. This is getting")
    |> mes("to be nonsense. Let's see,")
    |> mes("this message says, ''Green")
    |> mes("Herbs are very useful for")
    |> mes("getting rid of fish smells.''")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I got it...!")
    |> mes("Whoever made up")
    |> mes("these clues must be")
    |> mes("some sort of crazy man!")
    |> mes("It's the only explanation!")
    |> set_char_var(:HELLIONQ, 51)
    |> close()
  end
end
