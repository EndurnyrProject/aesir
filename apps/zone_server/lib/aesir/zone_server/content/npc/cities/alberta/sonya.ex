defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Sonya do
  @moduledoc """
  Randomly recounts one of Sonya's encounters with forest creatures.

  ## Behavior

  - Tells a story about a small creature, an enraged bear, or cooperative wolves.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 62, y: 156, dir: 2, sprite: 102, name: "Sonya", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Sonya]")

    case :rand.uniform(3) - 1 do
      0 -> tell_small_creature_story(ctx)
      1 -> tell_bear_story(ctx)
      2 -> tell_wolf_story(ctx)
      _ -> ctx
    end
  end

  defp tell_small_creature_story(ctx) do
    ctx
    |> mes(
      "Hey, you know, this one time I was walking through the forest and I saw this little green stem moving around."
    )
    |> next()
    |> mes("[Sonya]")
    |> mes(
      "I went to see what it was and when I went to touch it. The stem actually slapped my hand!"
    )
    |> next()
    |> mes("[Sonya]")
    |> mes(
      "It startled me, so I jumped back a bit and then I realized it wasn't a stem, but a very small animal."
    )
    |> next()
    |> mes("[Sonya]")
    |> mes("I was lucky I didn't upset it. Even the smallest animal can be dangerous if angered.")
    |> close()
  end

  defp tell_bear_story(ctx) do
    ctx
    |> mes("You know those lazy looking bears that live in the forest on the way to Payon?")
    |> next()
    |> mes("[Sonya]")
    |> mes(
      "Just for fun, I threw a rock at it and all of sudden it rushed at me! I was sooooo scared, I started to run away, then BAM!!!"
    )
    |> next()
    |> mes("[Sonya]")
    |> mes(
      "It ran into a low tree branch and knocked itself out! I swear, I'll never provoke an animal for fun again!"
    )
    |> close()
  end

  defp tell_wolf_story(ctx) do
    ctx
    |> mes("I once saw a pack of wolves take on one of those huge, lazy bears!")
    |> next()
    |> mes("[Sonya]")
    |> mes(
      "Wolves are much more cooperative than they may seem. If one of them is attacked, then any nearby wolves will run to help."
    )
    |> next()
    |> mes("[Sonya]")
    |> mes(
      "I'd think twice if you ever want to fight one when others of its kind are around. Be careful: don't get ganged up on!"
    )
    |> close()
  end
end
