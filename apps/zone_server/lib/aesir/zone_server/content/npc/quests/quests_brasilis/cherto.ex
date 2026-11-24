defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Cherto do
  @moduledoc """
  Cherto shares the legend of the guarana kid and guides the search.

  ## Behavior

  - Tells the guarana legend and directs adventurers to the mage Paje.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "bra_in01", x: 95, y: 179, dir: 3, sprite: 477, name: "Cherto", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_gua, 0) do
      stage when stage <= 1 -> introduction(ctx)
      2 -> guarana_legend(ctx)
      3 -> find_the_kid(ctx)
      4 -> consult_paje(ctx)
      _ -> ctx |> mes("[Cherto]") |> mes("hoho tickle~tickle~~~~!!!") |> close()
    end
  end

  defp introduction(ctx) do
    ctx =
      ctx
      |> mes("[Cherto]")
      |> mes("Hmm... hey man, you are from outside, aren't you?")
      |> next()
      |> mes("[Cherto]")
      |> mes("Cherto can figure it out even if it's the first time. You can't trick Cherto.")
      |> mes("Cherto has sharp eyes like an eagle! Hahaha!")
      |> next()
      |> mes("[Cherto]")
      |> mes("Ok, ok. Yes, yes. I see!")
      |> next()
      |> mes("[Cherto]")
      |> mes("Anyway, you arrived in Brasilis but don't know what to do?")
      |> mes("Am I right?")
      |> mes(
        "You don't know how fortunate you are to have found a really proper helper as myself."
      )
      |> next()
      |> mes("[Cherto]")
      |> mes(
        "Cherto takes it by your expression that you want to say, ''You are a master!'' Right?"
      )
      |> mes("Cherto, I can read and figure out all at once! That is written in your face!")
      |> next()

    if get_char_var(ctx, :brazil_gua, 0) == 0 do
      ctx
      |> mes("[Cherto]")
      |> mes("Cherto would love to stay here and explain everything to you but he is a busy man.")
      |> close()
    else
      guarana_history(ctx)
    end
  end

  defp guarana_history(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Cherto]")
      |> mes(
        "If you have a curious thing to ask to Cherto. Cherto will be kind enough to answer."
      )
      |> next()
      |> select(["Guarana?"])

    {ctx, _} =
      ctx
      |> mes("[Cherto]")
      |> mes("What? Do you want to find a guarana?")
      |> next()
      |> mes("[Cherto]")
      |> mes(
        "Guarana is only raised in this area, it has a soft inside and is coverd with a light fur."
      )
      |> mes("It seems a little bit weird but the flower is really big and smells beautiful.")
      |> next()
      |> mes("[Cherto]")
      |> mes(
        "A long time ago, guarana was used to relieve desease and thirst. But recently it's getting popular to revitalize body power and increase blood circulation."
      )
      |> next()
      |> mes("[Cherto]")
      |> mes(
        "Although it has such great effects, Cherto is sorry to inform you that we can't get it anymore."
      )
      |> next()
      |> select(["Whaaaat??"])

    {ctx, _} =
      ctx
      |> mes("[Cherto]")
      |> mes("For a while now, guarana berries haven't been growing here.")
      |> next()
      |> mes("[Cherto]")
      |> mes("Even if Cherto managed to find one, it will rot quickly.")
      |> next()
      |> mes("[Cherto]")
      |> mes("If only it didn't happen!")
      |> next()
      |> select(["What are you talking about?"])

    ctx
    |> mes("[Cherto]")
    |> mes("Quiet!!!!!!!!!!!!!!!!")
    |> mes("This story has been forbidden! Someone might be listening to our conversation...")
    |> next()
    |> mes("[Cherto]")
    |> mes(
      "If Cherto tells you, you might get us into trouble. But you look like you really wanna know so let me give you a tip."
    )
    |> mes("Come closer. Cherto will whisper so nobody can listen in.")
    |> set_char_var(:brazil_gua, 2)
    |> close()
  end

  defp guarana_legend(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Cherto]")
      |> mes("A Guarana boy was born.")
      |> next()
      |> select(["Guarana kid?"])

    ctx
    |> mes("[Cherto]")
    |> mes("There was woman who was an expert botanist.")
    |> mes("The woman was really popular to all living creatures.")
    |> next()
    |> mes("[Cherto]")
    |> mes(
      "At around the time her baby was born, she started a guarana farm. For some reason, her brothers were jealous so they destroyed the farm and disappeared."
    )
    |> mes("That kind of story...")
    |> next()
    |> mes("[Cherto]")
    |> mes(
      "We can't be sure that baby was born in the world but since that time, all guarana in Brasilis disappeared."
    )
    |> next()
    |> mes("[Cherto]")
    |> mes("Who is the guarana kid?")
    |> mes("Pedro who is famous as a greedy man?")
    |> mes("Meto who can't endure about all the fruits?")
    |> mes("Hovenue who is gloomy?")
    |> mes("They might know~!")
    |> next()
    |> mes("[Cherto]")
    |> mes("What about you?")
    |> mes("Who is the guarana kid?")
    |> mes("Will you figure out it? hohohhhhh~")
    |> set_char_var(:brazil_gua, 3)
    |> changequest(2192, 2193)
    |> close()
  end

  defp find_the_kid(ctx) do
    ctx
    |> mes("[Cherto]")
    |> mes("Can you find the guarana kid?")
    |> mes("Maybe yes? Maybe no?")
    |> close()
  end

  defp consult_paje(ctx) do
    ctx =
      ctx
      |> mes("[Cherto]")
      |> mes("Did you find guarana kid?")
      |> next()
      |> mes("- I tell Cherto about the kid making animal-like sounds. -")
      |> next()
      |> mes("[Cherto]")
      |> mes("Hoooh. That's unbelievable.")
      |> mes("That kid might be a guarana kid. Sure...")
      |> mes("According to the story the kid can have conversations with animals.")
      |> next()
      |> mes("[Cherto]")
      |> mes("If he can make crying sounds of animals, they might be able to converse!")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Now, what can I do?")
    |> mes("If he is the kid from the legend, is there any way to raise the guarana again?")
    |> next()
    |> mes("[Cherto]")
    |> mes("Haha!! What'd Cherto say?")
    |> mes("Cherto knows all~!!")
    |> mes("Cherto's already thought")
    |> mes("of the next step.")
    |> next()
    |> mes("[Cherto]")
    |> mes("In Brasilis there is an expert Mage.")
    |> mes("His name is Paje.")
    |> mes("Take this note over to him.")
    |> mes("He will show the solution for you and the kid.")
    |> set_char_var(:brazil_gua, 5)
    |> changequest(2194, 2195)
    |> close()
  end
end
