defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Bard do
  @moduledoc """
  Nelliorde the Bard opens the Brisingamen Seal quest by recommending adventurers to Mr. Kaili.

  ## Behavior

  - While the Brisingamen seal can be broken, an adventurer of base level 70 or more who has not
    started the quest can accept a letter of recommendation to Mr. Kaili, starting the quest.
  - Adventurers on the quest hear a story or a song; those past the recommendation stage can
    also pick a free song or hear news about Rune-Midgarts.
  - Otherwise he chats about himself, shares news and sings one of three songs for 500 zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_fild08",
        x: 175,
        y: 374,
        dir: 3,
        sprite: 51,
        name: "Bard",
        scope: :shared,
        unique_name: "Bard#brising"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, "god_nelluad01", 2)

    cond do
      not seal_quest_open?(ctx) -> stranger_greeting(ctx)
      get_char_var(ctx, :god_brising, 0) > 49 -> after_recommendation(ctx)
      get_char_var(ctx, :god_brising, 0) > 0 -> kaili_reminder(ctx)
      true -> kaili_rumor(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp seal_quest_open?(ctx) do
    get_server_var(ctx, "God2", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
      get_server_var(ctx, "God3", 0) < get_server_temp_var(ctx, "god_check2", 0)
  end

  defp finish(ctx) do
    ctx
    |> close2()
    |> cutin("", 255)
  end

  defp after_recommendation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Oh, I guess all is going well for you. So how has everything else been?")
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "I may be being overly sensitive, but it feels like something might happen soon. Aaah, don't mind me. It's no big deal. Maybe I'm just being weird."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes("Right, right, let me play a song for you. Would you care to listen?")
      |> next()
      |> select(["Sure, why not~", "How about some news?", "No thanks."])

    case choice do
      1 ->
        free_songs(ctx)

      2 ->
        quest_news(ctx)

      3 ->
        ctx
        |> mes("[Nelliorde]")
        |> mes("Huh? Okay then, talk to you later. May Bragi bless you on your journeys.")
        |> finish()

      _ ->
        ctx
    end
  end

  defp free_songs(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("So, which song")
      |> mes("would you like to hear?")
      |> mes("Go ahead, pick one~")
      |> next()
      |> select([
        "Bragi's Poem",
        "Eternal Chaos",
        "Assassin in the Sunset",
        "Der Ring des Nibelungen"
      ])

    case choice do
      1 ->
        ctx
        |> bragis_poem()
        |> finish()

      2 ->
        ctx
        |> cutin("god_nelluad02", 2)
        |> mes("[Nelliorde]")
        |> mes("Eternal Chaos...")
        |> mes("Sounds too chaotic.")
        |> mes("By the way, I wonder")
        |> mes("what the title really")
        |> mes("means. Is it the chaos")
        |> mes("of hell or our own reality?")
        |> soundeffect("chaos_of_eternity.wav", 1)
        |> finish()

      3 ->
        ctx
        |> cutin("god_nelluad02", 2)
        |> mes("[Nelliorde]")
        |> mes("Assassin in the Sunset!")
        |> mes(
          "Yes, no one looks cooler than an Assassin, the bringer of death, standing alone in the sunset! Heh heh~"
        )
        |> soundeffect("assassin_of_sunset.wav", 1)
        |> finish()

      4 ->
        ring_des_nibelungen(ctx)

      _ ->
        ctx
    end
  end

  defp bragis_poem(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Nelliorde]")
    |> mes("Bragi's Poem!")
    |> mes("What a good choice!")
    |> mes("I must say this song")
    |> mes("represents the")
    |> mes("heart of a poet!")
    |> soundeffect("bragis_poem.wav", 1)
  end

  defp ring_des_nibelungen(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Nelliorde]")
    |> mes("Der Ring des Nibelungen.....")
    |> mes("Okay, are you ready to listen?")
    |> mes("Hum hum hum....")
    |> next()
    |> soundeffect("ring_of_nibelungen.wav", 1)
    |> mes("^4D4DFFRheingold...")
    |> mes("Hidden in the Rhein river.")
    |> mes("If made into a ring,")
    |> mes("Could rule the world~^000000")
    |> next()
    |> mes("^4D4DFFProtected by a spell")
    |> mes("Cursing its thief")
    |> mes("To never find love.")
    |> mes("Alberich had known")
    |> mes("Nonetheless stole it.")
    |> mes("Love was forsaken for power.^000000")
    |> next()
    |> mes("^4D4DFFGiants built beautiful Valhalla")
    |> mes("Matrimony with Freya")
    |> mes("Goddess of beauty")
    |> mes("Their supposed payment.")
    |> mes("In not receiving it")
    |> mes("They forcefully took her.^000000")
    |> next()
    |> mes("^4D4DFFThe gods would")
    |> mes("give Alberich's treasure")
    |> mes("To the Giants for Freya's return.")
    |> mes("Loki tricked Alberich,")
    |> mes("Stealing his ring or power.^000000")
    |> next()
    |> mes("^4D4DFFBut Alberich cursed his ring")
    |> mes("Before it was returned to him,")
    |> mes("Envy and death would")
    |> mes("befall its wearers.^000000")
    |> next()
    |> mes("^4D4DFFThe ring was given to the giants")
    |> mes("Freya was returned to the gods")
    |> mes("The giants killed themselves")
    |> mes("Fighting over the rheingold,")
    |> mes("Victims of Alberich's curse~^000000")
    |> finish()
  end

  defp quest_news(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Some news you say..")
      |> mes("What kind of news do")
      |> mes("you wish to hear about?")
      |> next()
      |> select([
        "About Prontera!",
        "About coastal areas.",
        "Is the desert still hot?",
        "How about the borderlands?"
      ])

    case choice do
      1 -> quest_prontera_news(ctx)
      2 -> quest_coastal_news(ctx)
      3 -> quest_desert_news(ctx)
      4 -> quest_borderland_news(ctx)
      _ -> ctx
    end
  end

  defp quest_prontera_news(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes("What?! Prontera?!")
    |> mes("Can you not see that the front")
    |> mes(
      "gate of Prontera is right before you? You should at least know where you are, adventurer."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Anyways, I have one interesting news about Prontera. But, it's a secret. Shh! Are you... Single?"
    )
    |> next()
    |> cutin("god_nelluad04", 2)
    |> mes("[Nelliorde]")
    |> mes(
      "If so, go visit the tavern. I met a guy there who took to me a nice place. Oh yes. He took me to 'the place' where singles are forbidden~!"
    )
    |> finish()
  end

  defp quest_coastal_news(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes("Coastal areas?")
    |> mes(
      "That's a funny question. I mean, there's Alberta and a few other places where you can see the sea."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("To the southwest there's")
    |> mes("Kokomo Beach. But, I suppose it's too dangerous just to go there to take a stroll.")
    |> next()
    |> mes("[Nelliorde]")
    |> cutin("god_nelluad03", 2)
    |> mes("Kokomo Beach is a large")
    |> mes(
      "expanse of sand. The nearby water is filled with sea animals, so you can enjoy catching Shellfishes."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "However, there are always bullies in that kind of place. Once, I met a threatening looking hoodlum with red spiky hair."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> cutin("god_nelluad04", 2)
    |> mes(
      "He was chewing on something and spat it on the ground. The big buffoon managed to intimidate me into giving him all of my Zeny!"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("This world is too")
    |> mes("dangerous for a young")
    |> mes("and fragile Bard.")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "By the way, Alberta doesn't seem to have changed. The Sunken Ship looks the same as well, with all of its Skeleton Pirates and whatnot. You know how it is."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> cutin("god_nelluad01", 2)
    |> mes(
      "The event agency in charge of expeditions into the Sunken Ship is still making tons of money. If you have nothing to do, why don't you hunt for monsters down there?"
    )
    |> finish()
  end

  defp quest_desert_news(ctx) do
    ctx =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Oh, hell yes!")
      |> mes("When is it not?")
      |> mes("The desert is hot, has")
      |> mes("been hot and probably")
      |> mes("always will be...!")
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "Giant worms still jump out of nowhere, freaking out innocent travellers like myself, and the Sandmen still kick people in the, well... You know where."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "Even if the desert is filled with hideous monsters, the view of the ocean there is so magnificent. Hah, it makes me want to play a song."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes("I must say there is")
      |> mes("one place you may wish")
      |> mes("to see in the desert.")
      |> next()
      |> mes("[Nelliorde]")
      |> cutin("god_nelluad02", 2)
      |> mes(
        "I'm talking about the Assassin Guild. Supposedly, it's hidden behind a sandstorm in the Morocc Desert!"
      )

    if assassin?(ctx) do
      ctx
      |> mes(
        "But you should know what I am talking about! So when are you gonna take me to the guild, eh?"
      )
      |> finish()
    else
      ctx
      |> mes("Have you ever been there before?")
      |> finish()
    end
  end

  defp quest_borderland_news(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes("Well, to the north is the Schwaltzwald Republic.")
    |> mes("There, you'll find Juno,")
    |> mes("the 'City of Sages.'")
    |> next()
    |> mes("[Nelliorde]")
    |> cutin("god_nelluad03", 2)
    |> mes("The people there say that there is one major nuisance, a man known as")
    |> mes(
      "the 'Mad Scientist.' He's antisocial and creates a lot of public disturbances with his experiments."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("It seems everyone in Juno")
    |> mes(
      "hates him with a passion. Even one of the Tool Shop owners begged a passing adventurer to stop this Mad Scientist's research!"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "But I have a different opinion about him. I believe it's not a good idea to interrupt the work of any scientist."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "After all, he might just discover something important, even if his experiments are a little hazardous."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("Speaking of discoveries, you know how Juno floats in the air, right?")
    |> next()
    |> mes("[Nelliorde]")
    |> cutin("god_nelluad01", 2)
    |> mes("It's said that a piece of Ymir's Heart generates enough power")
    |> mes("to keep the entire city aloft in the sky. Isn't that amazing?")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Even more recent is the news about the discovery of Ymir's Book. You can read it in Juno's Sage Castle. I hear that it contains the secret to meeting Valkyrie..."
    )
    |> finish()
  end

  defp kaili_reminder(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("So, have you")
      |> mes("met Mr. Kaili?")
      |> mes("Please do your best.")
      |> mes("After all, I especially")
      |> mes("recommended you~")
      |> next()
      |> select(["Tell me a story.", "Sing a song for me."])

    case choice do
      1 ->
        ctx
        |> story_opening()
        |> mes("[Nelliorde]")
        |> mes("Oh my God...")
        |> mes("If I had known")
        |> mes("better, I would have")
        |> mes("never gone inside that place...")
        |> next()
        |> story_ant_hell_to_knock()
        |> mes("[Nelliorde]")
        |> cutin("god_nelluad03", 2)
        |> story_lunatic_to_rogues()
        |> mes("[Nelliorde]")
        |> cutin("god_nelluad01", 2)
        |> story_ending()

      2 ->
        favorite_song(ctx)

      _ ->
        ctx
    end
  end

  defp kaili_rumor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Say...")
      |> mes("Have we met before?")
      |> mes("Hmm? Never? Well...")
      |> mes("That's rather odd.")
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "I seem to recall that you've asked me to give you some information if I ever have any. Well, now I have and shall share it with you~"
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "The usefulness of this information all depends on you. Now, have you heard of the ^3333CCMonster Research Organization^000000?"
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "I happened to get this information from its headquarters in Juno. So how does that sound?"
      )
      |> next()
      |> select(["Wee~ I want to hear!", "Booooring~"])

    case choice do
      1 -> kaili_rumor_details(ctx)
      2 -> boring_reply(ctx)
      _ -> ctx
    end
  end

  defp kaili_rumor_details(ctx) do
    ctx =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Well...!")
      |> mes("You seem to be")
      |> mes("very excited about")
      |> mes("this new tidbit of")
      |> mes("knowledge I have~")
      |> next()

    if base_level(ctx) < 70 do
      ctx
      |> cutin("god_nelluad03", 2)
      |> mes("[Nelliorde]")
      |> mes(
        "Alas, this information doesn't seem to be very valuable to someone such as yourself."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "I'm so very sorry to have excited you, but only people that are strong enough to handle grueling work can benefit from this."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "Why don't you travel around and gain more experiences? I will let you know when you're ready, you know~"
      )
      |> finish()
    else
      offer_recommendation(ctx)
    end
  end

  defp offer_recommendation(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("god_nelluad02", 2)
      |> mes("[Nelliorde]")
      |> mes("Ooh...")
      |> mes("And you look")
      |> mes("like you can handle")
      |> mes("this kind of information.")
      |> mes("I'll share everything I know!")
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "One day, an adventurer discovered a strange, mysterious object. Unable to figure out what it could do, he visited the Monster Organization."
      )
      |> next()
      |> cutin("god_nelluad01", 2)
      |> mes("[Nelliorde]")
      |> mes(
        "There, it was entrusted to a scholar by the name of Mr. Kaili. He still hasn't uncovered the truth about that item and wishes for assistance in his investigation."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "Mr. Kaili suspects that the item might be part of an undiscovered ancient relic. Fortunately, he is also researching ancient relics as a project assigned by the royal court."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "So what do you think? Isn't that interesting? Of course, you'd better speak to Mr. Kaili if you wish to learn more. If you'd like, I shall write you a letter or recommendation."
      )
      |> next()
      |> select(["Sure! Sounds good.", "Sorry, I am not that interested."])

    case choice do
      1 ->
        ctx
        |> mes("[Nelliorde]")
        |> mes("Excellent...!")
        |> mes("So your name is...")
        |> mes("#{char_name(ctx, 0)}?")
        |> next()
        |> mes("[Nelliorde]")
        |> mes(
          "Alright, I shall contact him right away! Oh, and you can find the Monster Organization west of Juno's central plaza. It shouldn't be hard to find. Good luck!"
        )
        |> set_char_var(:god_brising, 1)
        |> finish()

      2 ->
        ctx
        |> cutin("god_nelluad02", 2)
        |> mes("[Nelliorde]")
        |> mes(
          "Ah, it's disappointing to hear that. I thought that you'd be perfect to help out Mr. Kaili. Oh well, talk to you later~"
        )
        |> finish()

      _ ->
        ctx
    end
  end

  defp boring_reply(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Boring, you say?")
      |> mes("Perhaps, but not as")
      |> mes("boring as an adventurer")
      |> mes("that passes up a chance")
      |> mes("for an adventure, yes?")
      |> next()
      |> select(["Tell me a story.", "Sing a song for me."])

    case choice do
      1 ->
        ctx
        |> story_opening()
        |> mes("[Nelliorde]")
        |> mes("Oh my God...")
        |> mes("If I had known")
        |> mes("better, I never")
        |> mes("would have gone")
        |> mes("inside that place...")
        |> next()
        |> story_ant_hell_to_knock()
        |> cutin("god_nelluad04", 2)
        |> mes("[Nelliorde]")
        |> story_lunatic_to_rogues()
        |> cutin("god_nelluad01", 2)
        |> mes("[Nelliorde]")
        |> story_ending()

      2 ->
        favorite_song(ctx)

      _ ->
        ctx
    end
  end

  defp story_opening(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Nelliorde]")
    |> mes("Hmm. What would")
    |> mes("be a good story for")
    |> mes(
      "you this time...? Ah yes, I've got it. Let me tell you about one of my own adventures. It was a pretty amazing experience."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "I went to Morocc, the city of the desert. On my way there, I became exhausted from the heat. Luckily, I found a hole beneath the shadows and climbed in to rest."
    )
    |> next()
  end

  defp story_ant_hell_to_knock(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes(
      "I actually crawled into the infamous ^FF0000Ant Hell^000000! I don't sound like a coward to you, do I?"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Well, the ants aren't the only ones living there. I wasn't afraid of them at all. Except, of course, when they attacked in groups."
    )
    |> next()
    |> cutin("god_nelluad03", 2)
    |> mes("[Nelliorde]")
    |> mes(
      "What I was really afraid of was this type of strawberry colored... tongue thing. Phreeoni!"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Fortunately, I survived the whole incident, although I still have nightmares of that man-sized tongue."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Once I got out of there, I craved human companionship to restore my sense of normalcy. The closest place that I knew was Paros Lighthouse."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Yet again, I decided to traverse the desert, despite the fact that the Kafra Ladies provide a very convenient teleport service there."
    )
    |> next()
    |> cutin("god_nelluad01", 2)
    |> mes("[Nelliorde]")
    |> mes(
      "Anyway, the fortress of Sandaruman is on the way to Paros Lighthouse. I remember Serutero, a guy I met in south Morocc, telling me about its scenic beauty."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("I was so excited")
    |> mes("about seeing it")
    |> mes("for myself. After all, doesn't 'Sandaruman' sound like the")
    |> mes("name of a beautiful place?")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "But I immediately regretted my decision once I arrived. Of course, the view was breathtaking: the sandy hills near the ocean, as"
    )
    |> mes("well as the ruins.")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "And of course I forgot Serutero's warning about all the monsters. Argh! It was a nightmare! Instead of enjoying the scenary, I ended up running for my life."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("I was still trying to escape those monsters when I stumbled upon")
    |> mes("an old house, West of Sandaruman, that seemed to be in a state of decay.")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "I recalled that Serutero said that no one was living in that area, so I began to worry a bit. Still, I was desperate and needed refuge."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "In my panic, I violently knocked on the door and screamed for someone to let me inside. Then do you know what I heard?"
    )
    |> next()
  end

  defp story_lunatic_to_rogues(ctx) do
    ctx
    |> mes("^FF0000Who's there?!")
    |> mes("Who would dare to intrude")
    |> mes("upon my territory?^000000")
    |> mes("I was freaked out! Whoever owned that house must have been some")
    |> mes("kind of lunatic!")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Th-then, with the specter of Death nipping at my heels, he told me to get lost! Luckily, I was saved by a mysterious, wandering SuperNovice, but that's another story."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "In any case, I finally arrived at Paros Lighthouse. There, I learned that the old house was a secret camp for the Rogue Guild. "
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "It's amazing, how they can live in such dangerous areas. Only Rogues would be able to survive there, you know?"
    )
    |> next()
  end

  defp story_ending(ctx) do
    ctx
    |> mes("Ah...")
    |> mes(
      "I'm so tired from talking so much. But if I happen to have another adventure, I shall share that tale with you."
    )
    |> finish()
  end

  defp favorite_song(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Nelliorde]")
    |> mes("Ah, you wish")
    |> mes("to hear a song?")
    |> mes("Okay! I shall then")
    |> mes("perform my favorite.")
    |> next()
    |> mes("[Nelliorde]")
    |> mes("I chased after fame.")
    |> mes("It eluded me.")
    |> mes("I ran after happiness")
    |> mes("But never caught it.")
    |> next()
    |> mes("[Nelliorde]")
    |> mes("But tomorrow will still")
    |> mes("Be there, I'm sure.")
    |> mes("Like the Water Mill")
    |> mes("In Al De Baran")
    |> mes("Which turns as")
    |> mes("Life goes on.")
    |> next()
    |> cutin("god_nelluad04", 2)
    |> mes("[Nelliorde]")
    |> mes("Cheer up! Life goes on.")
    |> mes("As surely as the Water")
    |> mes("Mill turns, tomorrow")
    |> mes("Will come.")
    |> finish()
  end

  defp stranger_greeting(ctx) do
    ctx =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Hello there!")
      |> mes("Isn't it such")
      |> mes("a glorious day?")
      |> mes("You know of me,")
      |> mes("do you not?")
      |> next()
      |> mes("[Nelliorde]")

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("Hahahaha, forgive my rudeness,")
        |> mes("but I fail to remember your name, although your face does seem rather familiar.")
      else
        ctx
        |> mes("Oh well well...")
        |> mes("How could I ever")
        |> mes("forget the lovely")
        |> mes("#{char_name(ctx, 0)}?")
      end

    {ctx, choice} =
      ctx
      |> next()
      |> cutin("god_nelluad01", 2)
      |> mes("[Nelliorde]")
      |> mes(
        "So, aren't you curious about me? Feel free to ask me whatever you like! I'm the vagabond that will wander the earth till the end of his days, your friend who loves to sing under the moonlight~"
      )
      |> next()
      |> select(["Who are you?", "What's new?", "Can you sing?"])

    case choice do
      1 -> introduce_himself(ctx)
      2 -> stranger_news(ctx)
      3 -> paid_songs(ctx)
      _ -> ctx
    end
  end

  defp introduce_himself(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes("Why, I am Nelliorde, the Bard.")
    |> mes("In truth, my real name is Elliorde.")
    |> next()
    |> cutin("god_nelluad03", 2)
    |> mes("[Nelliorde]")
    |> mes(
      "However, while I was singing at a Tavern, as per usual, a man with long blonde hair angrily demanded that I change my name!"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Never before have I seen such a flailing and a fuss over someone coincidentally sharing the same name!"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("And so, that little altercation")
    |> mes("was settled with me being named Nelliorde.")
    |> next()
    |> cutin("god_nelluad04", 2)
    |> mes("[Nelliorde]")
    |> mes(
      "I don't sound like a coward to you, do I? Do you believe I should have fought for the right to keep my original name?"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "If so, you're wrong! I just don't believe that violence can solve anything, as the romantic Bard"
    )
    |> mes("that cherishes peace...")
    |> next()
    |> mes("^3355FFSeeing as it's not worth")
    |> mes("listening to Nelliorde's lies, you decide to simply tune him out.^000000")
    |> next()
    |> mes("^3355FF...")
    |> mes("......^000000")
    |> next()
    |> mes("^3355FF...")
    |> mes("......")
    |> mes(".........^000000")
    |> next()
    |> cutin("god_nelluad03", 2)
    |> mes("[Nelliorde]")
    |> mes("And that's how I convinced wise")
    |> mes(
      "and benevolent King Tristram III to build a paradise where married lovers could enjo--Hm? Are you even listening?!"
    )
    |> finish()
  end

  defp stranger_news(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("You wish to")
      |> mes("hear of some news?")
      |> mes("What kind of news do")
      |> mes("you wish to know about?")
      |> next()
      |> select([
        "About Prontera!",
        "About seaside areas.",
        "Is the desert still hot?",
        "How about the borderlands?"
      ])

    case choice do
      1 -> stranger_prontera_news(ctx)
      2 -> stranger_seaside_news(ctx)
      3 -> stranger_desert_news(ctx)
      4 -> stranger_borderland_news(ctx)
      _ -> ctx
    end
  end

  defp stranger_prontera_news(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes("What?! Prontera?!")
    |> mes("Can you not see that the front")
    |> mes(
      "gate of Prontera is right before you? You should at least know where you are, adventurer."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Anyways, I know one interesting bit of news about Prontera. But it's a secret. Shh! Are you... Single?"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "If so, go visit the tavern. I met a guy there who took me a nice place. Oh yes. He took me the place where singles are forbidden~!"
    )
    |> finish()
  end

  defp stranger_seaside_news(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes("Seaside areas?")
    |> mes(
      "That's a funny question. I mean, there's Alberta and a few other places where you can see the sea."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("To the southwest there's")
    |> mes("Kokomo Beach. But, I suppose it's too dangerous just to go there to take a stroll.")
    |> next()
    |> mes("[Nelliorde]")
    |> mes("Kokomo Beach is a large")
    |> mes(
      "expanse of sand. The nearby water is filled with sea animals, so you can enjoy catching Shellfishes."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "However, there are always bullies in that kind of place. Once, I met a threatening looking hoodlum with red spiky hair."
    )
    |> next()
    |> cutin("god_nelluad04", 2)
    |> mes("[Nelliorde]")
    |> mes(
      "He was chewing on something and spat on the ground. The big buffoon managed to intimidate me into giving him all of my Zeny!"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("This world is too")
    |> mes("dangerous for a young")
    |> mes("and fragile Bard.")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "By the way, Alberta doesn't seem to have changed. The Sunken Ship looks the same as well, with all of its Skeleton Pirates and whatnot. You know how it is."
    )
    |> next()
    |> cutin("god_nelluad01", 2)
    |> mes("[Nelliorde]")
    |> mes(
      "The event agency in charge of expeditions into the Sunken Ship is still making tons of money. If you have nothing to do, why don't you hunt for monsters down there?"
    )
    |> finish()
  end

  defp stranger_desert_news(ctx) do
    ctx =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Oh yes!")
      |> mes("When is it not?")
      |> mes("The desert is hot, has")
      |> mes("been hot and probably")
      |> mes("always will be...!")
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "Giant worms still jump out of nowhere, freaking out innocent travellers like myself, and the Sandmen still kick people in the, well... You know where."
      )
      |> next()
      |> cutin("god_nelluad02", 2)
      |> mes("[Nelliorde]")
      |> mes(
        "Even if the desert is filled with hideous monsters, the view of the ocean there is so magnificent. Hah, it makes me want to play a song."
      )
      |> next()
      |> mes("[Nelliorde]")
      |> mes("I must say there is")
      |> mes("one place you may wish")
      |> mes("to see in the desert.")
      |> next()
      |> mes("[Nelliorde]")
      |> mes(
        "I'm talking about the Assassin Guild. Supposedly, it's hidden behind a sandstorm in the Morocc"
      )

    if assassin?(ctx) do
      ctx
      |> mes(
        "Desert! But you should know what I am talking about! So when are you gonna take me to the guild, eh?"
      )
      |> finish()
    else
      ctx
      |> mes("Desert! Have you ever been there before?")
      |> finish()
    end
  end

  defp stranger_borderland_news(ctx) do
    ctx
    |> mes("[Nelliorde]")
    |> mes("Well, to the north is the Schwaltzwald Republic.")
    |> mes("There, you'll find Juno,")
    |> mes("the 'City of Sages.'")
    |> next()
    |> mes("[Nelliorde]")
    |> mes("The people there say that there is one major nuisance, a man known")
    |> mes(
      "as the 'Mad Scientist.' He's antisocial and creates a lot of public disturbances with his experiments."
    )
    |> next()
    |> cutin("god_nelluad03", 2)
    |> mes("[Nelliorde]")
    |> mes("It seems everyone in Juno hates")
    |> mes(
      "him with a passion. Even one of the Tool Shop owners begged a passing adventurer to stop this Mad Scientist's research!"
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "But I have a different opinion about him. I believe it's not a good idea to interrupt the work of any scientist."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "After all, he might just discover something important, even if his experiments are a little hazardous."
    )
    |> next()
    |> mes("[Nelliorde]")
    |> mes("Speaking of discoveries, you know how Juno floats in the air, right?")
    |> next()
    |> cutin("god_nelluad01", 2)
    |> mes("[Nelliorde]")
    |> mes("It's said that a piece of Ymir's Heart generates enough power")
    |> mes("to keep the entire city aloft in the sky. Isn't that amazing?")
    |> next()
    |> mes("[Nelliorde]")
    |> mes(
      "Even more recent is the news about the discovery of Ymir's Book. You can read it in Juno's Sage Castle. I hear that it contains the secret to meeting Valkyrie..."
    )
    |> finish()
  end

  defp paid_songs(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nelliorde]")
      |> mes("Can I sing, you ask?")
      |> mes("Certainly, and if I may say so, pleasureably. Which song would")
      |> mes("you care to hear?")
      |> next()
      |> select(["Bragi's Poem", "Eternal Chaos", "Assassin in the Sunset"])

    case choice do
      1 -> paid_song(ctx, &bragis_poem/1)
      2 -> paid_song(ctx, &eternal_chaos_on_request/1)
      3 -> paid_song(ctx, &assassin_in_the_sunset_on_request/1)
      _ -> ctx
    end
  end

  defp paid_song(ctx, perform) do
    if zeny(ctx) > 499 do
      ctx
      |> perform.()
      |> pay_zeny(500)
      |> finish()
    else
      ctx
      |> mes("[Nelliorde]")
      |> mes(
        "Please forgive me, but I cannot play a song for free. The world is harsh, and a frail Bard such as myself must have some means"
      )
      |> mes("to survive~")
      |> finish()
    end
  end

  defp eternal_chaos_on_request(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Nelliorde]")
    |> mes("You must like robust")
    |> mes("and energetic music, eh?")
    |> mes("As you wish~")
    |> soundeffect("chaos_of_eternity.wav", 1)
  end

  defp assassin_in_the_sunset_on_request(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Nelliorde]")
    |> mes("Excellent choice!")
    |> mes("Somehow, the image of")
    |> mes("the setting sun fits")
    |> mes("well with Assassins.")
    |> mes("Don't you agree?")
    |> soundeffect("assassin_of_sunset.wav", 1)
  end

  defp assassin?(ctx) do
    job = Rathena.job_id(class(ctx))
    job == Rathena.job_id(:assassin) or job == Rathena.job_id(:assassin_cross)
  end
end
