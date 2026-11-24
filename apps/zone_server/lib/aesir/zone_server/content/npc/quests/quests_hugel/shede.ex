defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Shede do
  @moduledoc """
  Shede asks adventurers to gather ingredients for her cookies.

  ## Behavior

  - Randomly requests mushrooms, clams, or bug shells and thanks the player on completion.
  - Introduces Herico after the player meets the prerequisite quests.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hugel", x: 70, y: 137, dir: 5, sprite: 879, name: "Shede", scope: :shared}]

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, "siide1.bmp", 2)
    progress = get_char_var(ctx, :hg_tre, 0)

    cond do
      progress == 0 ->
        introduction(ctx)

      progress in 10..14 ->
        mushroom_reminder(ctx)

      progress in 20..24 ->
        clam_reminder(ctx)

      progress in 30..34 ->
        bug_reminder(ctx)

      progress == 15 ->
        mushroom_thanks(ctx)

      progress == 25 ->
        clam_thanks(ctx)

      progress == 35 ->
        bug_thanks(ctx)

      progress == 40 and get_char_var(ctx, :lhz_boss, 0) == 44 and
          get_char_var(ctx, :lhz_curse, 0) > 30 ->
        introduce_herico(ctx)

      progress == 41 ->
        herico_reminder(ctx)

      true ->
        greeting(ctx)
    end
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shede]")
      |> mes("Yay~ are you talking to me? Yay!")
      |> mes("Hey, are you from a different city? Wow, nice to see you!")
      |> emotion(:surprise)
      |> next()
      |> mes("[Shede]")
      |> mes(
        "Ever since the airport was built, Hugel has been so busy to welcome tourists and adventurers."
      )
      |> mes("I am kind of surprised to see Hugel being so crowded like this,")
      |> mes("but I think that this is a good change for this town.")
      |> next()
      |> mes("[Shede]")
      |> mes("At the same time, I have so many customers to serve...")
      |> mes("In fact, I don't even have a time to cht-chat, hohoho.")
      |> next()
      |> select(["Do you want me to help you?", "I will leave you alone"])

    case choice do
      1 -> choose_favor(ctx)
      2 -> decline(ctx)
      _ -> ctx
    end
  end

  defp choose_favor(ctx) do
    ctx =
      ctx
      |> mes("[Shede]")
      |> mes("Oh~ how kind of you! Thank you so much~")
      |> mes("Then can I ask you a favor?")
      |> emotion(:throb)
      |> next()
      |> mes("[Shede]")

    case Enum.random(1..3) do
      1 -> mushroom_favor(ctx)
      2 -> clam_favor(ctx)
      3 -> bug_favor(ctx)
      _ -> decline(ctx)
    end
  end

  defp mushroom_favor(ctx) do
    ctx
    |> mes("Uncle Hollun's birthday is coming,")
    |> mes("so I want to make \"^3131FFMushroom Flavor Cookies^000000\" for him.")
    |> mes("Unfortunately, I am short of the most important ingredient, the Mushrooms.")
    |> next()
    |> cutin("siide2.bmp", 2)
    |> mes("[Shede]")
    |> mes("Ordinary mushrooms don't smell that good, but")
    |> mes(
      "\"^3131FFMoks Mushrooms^000000\" which only grow in Hugel have such appetizing scent."
    )
    |> mes(
      "So, when they are added to cookies, they enhance the taste of cookies so much better."
    )
    |> next()
    |> mes("[Shede]")
    |> mes(
      "Can you please go gather \"^3131FF5 Moks Mushroom Solution^000000\" from \"^3131FFMoks Mushrooms^000000\"?"
    )
    |> mes("You will find the mushrooms in fields near Hugel.")
    |> mes("I hope that you will bring their solution as quickly as you can!")
    |> set_char_var(:hg_tre, 10)
    |> close()
    |> cutin("", 255)
  end

  defp clam_favor(ctx) do
    ctx
    |> mes(
      "In fact, Agette and I am competing with each other for the Hugel's best cookie master position."
    )
    |> next()
    |> mes("[Shede]")
    |> mes("Becoming the best cookie mater is not an easy thing to achieve.")
    |> mes("Everyone can have the best ingredients and the best cooking utensils,")
    |> mes("but that doesn't mean that they can become the best cookie masters.")
    |> next()
    |> mes("[Shede]")
    |> mes("You need to know how to harmonize your skills and your senses")
    |> mes("to make the most delicious cookies.")
    |> next()
    |> cutin("siide2.bmp", 2)
    |> mes("[Shede]")
    |> mes("I dare to say that my cookies are the best.")
    |> mes("However, Agette is also a professional cookie baker.")
    |> next()
    |> mes("[Shede]")
    |> mes("If I hear her name while baking,")
    |> mes("it makes me shake my hands in anxiety")
    |> mes("so that I make a mistake to measure the right amount of ingredients.")
    |> mes("That explains how good she is at baking cookies.")
    |> next()
    |> mes("[Shede]")
    |> mes("Still, I am a proud cookie baker, and")
    |> mes("I can hear a voice from deep inside of me saying")
    |> mes("that I cannot be beat by her!")
    |> mes("Can you hear that?")
    |> mes("Can you hear my inner fighting spirit as a cookie baker?")
    |> next()
    |> mes("[Shede]")
    |> mes("I am going to compete with her")
    |> mes("for the Hugel's best cookie mater position after a while.")
    |> mes("So, I have been doing my best in practicing my skills to win her!")
    |> next()
    |> mes("[Shede]")
    |> mes("There were many obstacles in my way to become the best cookie baker.")
    |> mes("But, see? I am still here, alive and kicking! I will never give up! In that sense..")
    |> mes("I am going to challenge on baking ^FF0000Clam Cookies^000000 today!")
    |> mes(
      "I am going to make them taste tangy and unique. I am sure that they will be a great success!"
    )
    |> next()
    |> mes("[Shede]")
    |> mes("When you go to the beach, ")
    |> mes("you will find clams near the ferry.")
    |> mes("Please gather ^3131FF5 Clam Flesh^000000 from the clams.")
    |> mes("Please hurry!")
    |> set_char_var(:hg_tre, 20)
    |> close()
    |> cutin("", 255)
  end

  defp bug_favor(ctx) do
    ctx =
      ctx
      |> mes("In fact, I gave my heart to a gentleman.")
      |> mes("I think that the time has come to let him know")
      |> mes("how I feel about him.")
      |> next()
      |> cutin("siide2.bmp", 2)
      |> mes("[Shede]")
      |> mes("So, I decided to bake special cookies called...")
      |> mes("...... ^3131FFDevil's Cookies^000000!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Devil's Cookies?")
      |> next()
      |> cutin("siide1.bmp", 2)
      |> mes("[Shede]")
      |> mes("Yes, Devil's Cookies.")
      |> mes("When you go outside of Hugel, you will find \"^3131FFMoks Bugs^000000\"")
      |> mes("hiding in the bushes. They breed in this season, so they are plump with eggs.")
      |> next()
      |> mes("[Shede]")
      |> mes("When you stew their shells and use the broth to kneed flour,")
      |> mes("you can make fresh and crunch cookies.")
      |> next()
      |> cutin("siide2.bmp", 2)
      |> mes("[Shede]")
      |> mes("Devil's Cookies are so delicious, so they are rumored to dazzle the eaters with")
      |> mes(
        "the mysteriously crunch texture and the sweetness, and to allure them to hell without them knowing."
      )
      |> mes("Ah~ I hope that he will like them...")
      |> next()
      |> cutin("siide1.bmp", 2)
      |> mes("[Shede]")
      |> mes("Would you please help me to bake the cookies? I need 5 Moks Bug Shells~")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("'......I am confused...Does she love him or hate him?'")

    ctx
    |> emotion(:think, playerattached(ctx))
    |> set_char_var(:hg_tre, 30)
    |> close()
    |> cutin("", 255)
  end

  defp decline(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("No, it is fine. Somehow I needed a break, hohoh!")
    |> close()
    |> cutin("", 255)
  end

  defp mushroom_reminder(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes(
      "Can you please go gather \"^3131FF5 Moks Mushroom Solution^000000\" from \"^3131FFMoks Mushrooms^000000\"?"
    )
    |> mes("You will find the mushrooms in fields near Hugel.")
    |> mes("I hope that you will bring their solution as quickly as you can!")
    |> close()
    |> cutin("", 255)
  end

  defp clam_reminder(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("Please pick up \"^3131FF5 Clams^000000\" from a fish trap in the ferry.")
    |> mes("I hope that you will bring their solution as quickly as you can!")
    |> close()
    |> cutin("", 255)
  end

  defp bug_reminder(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("Please bring \"^3131FF5 Moks Bug Shells^000000\" from outside of Hugel.")
    |> mes("I hope that you will bring their solution as quickly as you can!")
    |> close()
    |> cutin("", 255)
  end

  defp mushroom_thanks(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("Oh! You came back earlier than I thought.")
    |> mes("Now, I can bake the Mushroom Flavor Cookies for uncle Hollun.")
    |> mes("Thank you so much.")
    |> emotion(:smile)
    |> set_char_var(:hg_tre, 40)
    |> close()
    |> cutin("", 255)
  end

  defp clam_thanks(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("Oh! You came back earlier than I thought.")
    |> mes("Now, I can bake the best cookies of mine and compete with Agette!")
    |> mes("Thank you so much.")
    |> emotion(:smile)
    |> set_char_var(:hg_tre, 40)
    |> close()
    |> cutin("", 255)
  end

  defp bug_thanks(ctx) do
    ctx =
      ctx
      |> mes("[Shede]")
      |> mes("Oh! You came back earlier than I thought.")
      |> mes("Now, I can bake Devil's Cookies to confess my love to the gentleman.")
      |> mes("Thank you so much.")
      |> emotion(:smile)
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("(If he knew what ingredients she used for the cookies,)")
      |> mes("(I am pretty sure that at least he will remember her face to avoid next time...)'")

    ctx
    |> emotion(:think, playerattached(ctx))
    |> set_char_var(:hg_tre, 40)
    |> close()
    |> cutin("", 255)
  end

  defp introduce_herico(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("Have you seen Mr. Herico?")
    |> mes("He is a lonesome old man who is staying at Hugel Inn.")
    |> next()
    |> mes("[Shede]")
    |> mes("If you have some time, why don't you go spend some time with him?")
    |> mes("I know that he will appreciate it.")
    |> set_char_var(:hg_tre, 41)
    |> close()
    |> cutin("", 255)
  end

  defp herico_reminder(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("Mr. Herico has an impediment in movement, so he usually stays in his room.")
    |> mes("Please go spend some time with him. I know that he will appreciate it.")
    |> close()
    |> cutin("", 255)
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Shede]")
    |> mes("So, how do you like Hugel?")
    |> mes("It is a peaceful village, isn't it?")
    |> close()
    |> cutin("", 255)
  end
end
