defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Kouji do
  @moduledoc """
  Sings songs that reflect the Amatsu quest progression.

  ## Behavior

  - Advances the quest at stage two and updates the quest log at stage three.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 189,
        y: 166,
        dir: 5,
        sprite: 764,
        name: "Kouji",
        scope: :shared,
        unique_name: "Kouji#ama"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Kouji]")
      |> mes("Ralralrah Ralralrah Ralralrahralralrah~")
      |> mes("Ralralrah Ralralrah Ralralrahralralrah~")
      |> next()
      |> mes("[Kouji]")

    ctx
    |> sing(get_char_var(ctx, :event_amatsu, 0))
    |> next()
    |> mes("[Kouji]")
    |> mes("Ralralrah Ralralrah Ralralrahralralrah~")
    |> mes("Ralralrah Ralralrah Ralralrahralralrah~")
    |> close()
  end

  defp sing(ctx, 1) do
    ctx
    |> mes("When you're sick, rice cakes are no good~")
    |> mes("Family is the best help, as it should~")
    |> mes("When medicine doesn't help, that's when you'll see~")
    |> mes("That Mommy's love is best for me~")
  end

  defp sing(ctx, 2) do
    ctx
    |> set_char_var(:event_amatsu, 3)
    |> mes("Priest, Priest~")
    |> mes("A fox is following me!")
    |> mes("It's funny and a little absurd,")
    |> mes("But I'll need noodles with fried bean curd!")
  end

  defp sing(ctx, 3) do
    ctx =
      ctx
      |> mes("Priest, priest~")
      |> mes("A fox is following me!")
      |> mes("If he doesn't leave when I scream and shout!")
      |> mes("The North Shrine Priest should help me out~")

    if isbegin_quest(ctx, 8132) == 1, do: changequest(ctx, 8132, 8133), else: ctx
  end

  defp sing(ctx, 4) do
    ctx
    |> mes("Priest, priest~")
    |> mes("A fox is following me.")
    |> mes("If shouts alone don't make Fox scared,")
    |> mes("I might need help from Tiger and Bear~!")
    |> next()
    |> mes("[Kouji]")
    |> mes("Anything else I need in this fight???")
    |> mes("Maybe some water from an Acolyte~!")
  end

  defp sing(ctx, 5) do
    ctx
    |> mes("Scary scary harbor ship~")
    |> mes("Empty of people, full of treasure~")
    |> mes("But I don't remember~!")
    |> mes("the rest of this...song???")
  end

  defp sing(ctx, _) do
    ctx
    |> mes("Blue roof under the blue sky")
    |> mes("Blue wall on the blue lake")
    |> mes("Blue wishes in the blue minds")
    |> mes("Blue Blue Everything is Blue")
  end
end
