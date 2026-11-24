defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.EnquroCarson do
  @moduledoc """
  Enquro Carson investigates the Mercenary Rebellion for Light News.

  ## Behavior

  - Shares information about the rebellion in exchange for drinks from Morocc.
  - Directs the player to Hugel to find a surviving mercenary.

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
    spawn: [
      %{map: "lhz_in03", x: 39, y: 44, dir: 3, sprite: 97, name: "Enquro Carson", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :hg_tre, 0)

    cond do
      progress < 45 -> ctx |> introduction() |> close()
      progress == 45 -> inquire(ctx)
      progress == 46 -> exchange_drinks(ctx)
      progress == 47 -> directions(ctx)
      true -> spelling(ctx)
    end
  end

  defp introduction(ctx) do
    ctx
    |> mes("[Enquro Carson]")
    |> mes("Hello, everyone. This is Enquro Carson")
    |> mes("from Light News.")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("People want to hear prompt and accurate news.")
    |> mes("I feel proud of myself as a news reporter")
    |> mes("especially when people are astonished by the news")
    |> mes("which I am delivering to them.")
  end

  defp inquire(ctx) do
    {ctx, choice} =
      ctx |> introduction() |> next() |> select(["Mercenary Rebellion", "News reporter job"])

    case choice do
      1 -> rebellion(ctx)
      2 -> reporter_job(ctx)
      _ -> ctx
    end
  end

  defp rebellion(ctx) do
    ctx =
      ctx
      |> mes("[Enquro Carson]")
      |> mes("Hmm...Mercenary Rebellion...?")
      |> mes("It happened pretty long time ago.")
      |> mes("Mercenary soldiers lost their jobs")
      |> mes("after guardians were invented.")
      |> mes("And they insisted their social security")
      |> mes("through a violent method, so the government had to stop them with force.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Do you know any survivor of Mercenary Rebellion?")
      |> next()
      |> mes("[Enquro Carson]")
      |> mes("Welll...I was not assigned to the case,")
      |> mes("and the news reporter who kept the coverage of the case")
      |> mes("retired long time ago...")
      |> mes("Oh, I think that I can check")
      |> mes("if he has left any documents about the rebellion.")
      |> mes("Give me a moment.")
      |> next()
      |> mes("- *Rummage Rummage* -")
      |> mes("- *Rummage Rummage* -")
      |> mes("- *Rummage Rummage* -")
      |> next()
      |> mes("[Enquro Carson]")
      |> mes("Oh! I found it.")
      |> next()
      |> mes("[Enquro Carson]")
      |> mes("Mr. Balparan, yes, he is the news reporter,")
      |> mes("must be greatly intrigued by the rebellion.")
      |> mes("According to this documents, he tried to")
      |> mes("contact with the rebellion survivors")
      |> mes("after the rebellion ended in failure.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Can you tell me the survivors' locations?")
      |> next()
      |> mes("[Enquro Carson]")
      |> mes("Well, I am not supposed to release")
      |> mes("any kind of personal information to outside.")
      |> mes("Hmm...but it happened a long time ago, and")
      |> mes("I don't know if they are still alive or not...")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Thank you so much!")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("Wait, wait, I didn't say that I would release their information yet.")
    |> mes("Actually my motto is that")
    |> mes("\"^3131FFEvery bit of information must be shared^000000\".")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("I hope that you are willing to share any information")
    |> mes("that you will find from the survivors with me.")
    |> mes("Oh yes, do you know what? \"Commutative contract\".")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("I heard of a private pub in Morocc,")
    |> mes("a city of Rune-Midgarts Kingdom")
    |> mes("that is not open to the public.")
    |> mes("People keep talking about the pub's best drink,")
    |> mes("and I wonder how delicious the drink will be.")
    |> mes("Can you please get me the drink? Hahaha, thanks!")
    |> set_char_var(:hg_tre, 46)
    |> close()
  end

  defp reporter_job(ctx) do
    ctx
    |> mes("[Enquro Carson]")
    |> mes(".......Hmmm...Hmmm...Hmmm.")
    |> next()
    |> mes("- Enquro Carson looks you up and down with squinting his eyes. -")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("You are not saying that you want to be a news reporter, are you?")
    |> close()
  end

  defp exchange_drinks(ctx) do
    if count_item(ctx, 12112) == 0 or count_item(ctx, 12113) == 0 do
      drink_reminder(ctx)
    else
      share_information(ctx)
    end
  end

  defp drink_reminder(ctx) do
    ctx
    |> mes("[Enquro Carson]")
    |> mes("I heard of a private pub in Morocc,")
    |> mes("a city of Rune-Midgarts Kingdom")
    |> mes("that is not open to the public.")
    |> mes("People keep talking about the pub's best drink,")
    |> mes("and I wonder how delicious the drink will be.")
    |> mes("Can you please get me the drink? Hahaha, thanks!")
    |> close()
  end

  defp share_information(ctx) do
    ctx =
      ctx
      |> mes("[Enquro Carson]")
      |> mes("Wow, this is that famous drink!")
      |> mes("Let's see...*Gulp*")
      |> next()
      |> emotion(:best)
      |> mes("[Enquro Carson]")
      |> mes("Wow! This is awsome!")
      |> mes("It is as delicious as I heard!")
      |> mes("Its taste is still lingering on my tongue,")
      |> mes("and it is like Wow!")
      |> next()
      |> mes("[Enquro Carson]")
      |> mes("Anyways, according to Mr. Balparan's documents,")
      |> mes("errr....yes, this must be the name of the last mercenary soldier.")
      |> mes("Mr. Balparan contacted with")
      |> mes("^3131FFWintzil Trony^000000,")
      |> mes("the last mercenary soldier for the last time in...")
      |> mes("^FF0000Hugel^000000. Wait, Hugel?")
      |> mes("Isn't that the small country at the corner of Schwarzwald Republic?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What? Hugel?")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("Previously, it was very difficult to get to Hugel")
    |> mes("because there was no safe route.")
    |> mes("Basically, the village was like an island within the continent,")
    |> mes("but ever since an airport was built there,")
    |> mes("the village is now having its period of prosperity.")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("You are lucky, you know that?")
    |> mes("Mr. Balparan gave up on meeting with the mercenary soldier")
    |> mes("in Hugel because it was too tough to just get there.")
    |> mes("But you, all you need to do is just getting on to the airship.")
    |> next()
    |> mes("[Enquro Carson]")
    |> mes("Oh, by the way, I hope that you will keep")
    |> mes("this secret between you and me.")
    |> mes("I released the personal information at my discretion,")
    |> mes("and I know that I am not allowed to do that. Hehe.")
    |> emotion(:kik)
    |> set_char_var(:hg_tre, 47)
    |> delitem(12112, 1)
    |> delitem(12113, 1)
    |> close()
  end

  defp directions(ctx) do
    ctx
    |> mes("[Enquro Carson]")
    |> mes("Just get on to the airship and go to Hugel.")
    |> mes("Hopefully you will meet with ^3131FFWintzil Trony^000000")
    |> mes("or his son...or something.")
    |> mes("Oh, be careful not to provoke him though.")
    |> mes("He used to be a mercenary soldier, and they were famed for their violence.")
    |> close()
  end

  defp spelling(ctx) do
    ctx
    |> mes("[Enquro Carson]")
    |> mes("This is very shameful for me to confess,")
    |> mes("but I tend to make lots and lots of spelling mistakes.")
    |> mes("Yeah, I know, it is a shame.")
    |> close()
  end
end
