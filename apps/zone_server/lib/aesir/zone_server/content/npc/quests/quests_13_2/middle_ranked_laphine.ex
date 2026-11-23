defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.MiddleRankedLaphine do
  @moduledoc """
  Flowery supplies a seed for Grenouille’s perfume quest.

  ## Behavior

  - Gives the seed during the appropriate quest stage and reminds the player to use it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in02",
        x: 139,
        y: 65,
        dir: 3,
        sprite: 438,
        name: "Middle-Ranked Laphine",
        scope: :shared,
        unique_name: "Middle-Ranked Laphine#la"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      is_equipped(ctx, 2782) != 1 or get_char_var(ctx, :ep13_2_rhea, 0) != 100 ->
        untranslated_greeting(ctx)

      checkweight(ctx, [{1201, 1}]) == 0 ->
        overweight(ctx)

      get_char_var(ctx, :ep13_2_tre1, 0) == 1 ->
        give_seed(ctx)

      get_char_var(ctx, :ep13_2_tre1, 0) == 2 ->
        seed_reminder(ctx)

      true ->
        greeting(ctx)
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("[Flowery]")
    |> mes("It looks like you're carrying too many things.")
    |> mes("Why not put some of your items in storage and come back?")
    |> close()
  end

  defp give_seed(ctx) do
    ctx
    |> mes("[Flowery]")
    |> mes("Huh? Seed of the flower of Alfheim?")
    |> mes("Do I have that one? Hmm~")
    |> next()
    |> mes("[Flowery]")
    |> mes("As you see, there're so many stuffs")
    |> mes("in my room, so I don't know")
    |> mes("exactly what I have")
    |> mes("or not in my room.")
    |> next()
    |> mes("[Flowery]")
    |> mes("But I'll try to find cuz you came")
    |> mes("here to help Grenouille")
    |> mes("He's always pretend to tenacious,")
    |> mes("but sometimes he help others well! Huhu!")
    |> next()
    |> mes("- rummaging -")
    |> emotion(:think)
    |> next()
    |> mes("- rummaging -")
    |> mes("- rummaging -")
    |> emotion(:think)
    |> next()
    |> mes("- rummaging -")
    |> mes("- rummaging -")
    |> mes("- rummaging -")
    |> emotion(:aha)
    |> next()
    |> mes("[Flowery]")
    |> mes("Wow! Come here!")
    |> mes("I found a seed!")
    |> next()
    |> mes("[Flowery]")
    |> mes("Hmm... But this one is")
    |> mes("one of the most common and trifle")
    |> mes("kind in Alfheim, so you can find")
    |> mes("this wild flower at anywhere...")
    |> mes("This one would be ok?")
    |> next()
    |> mes("[Flowery]")
    |> mes("Umm.. But I don't have")
    |> mes("any other seed of flower..")
    |> mes("So, just bring this, here you are~")
    |> set_char_var(:ep13_2_tre1, 2)
    |> give_item(7193, 1)
    |> close()
  end

  defp seed_reminder(ctx) do
    ctx
    |> mes("[Flowery]")
    |> mes("I gave you the seed, so it's up to you that what would you do with the seed.")
    |> mes("I feel dizzy when I look at my room.")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Flowery]")
    |> mes("Yuuuum~")
    |> mes(
      "Can you believe that right in front of us is a battle field? Though it's very silent and peaceful at the moment. So do I~"
    )
    |> close()
  end

  defp untranslated_greeting(ctx) do
    ctx
    |> mes("[Middle-Ranked Laphine]")
    |> mes("NeiKoFulo An DielOdesMush Or KoDanaOsa Ir FarBurnes Ir ")
    |> mes("NeOsaVa Mu BurVeTi Ra OsaDeh")
    |> close()
  end
end
