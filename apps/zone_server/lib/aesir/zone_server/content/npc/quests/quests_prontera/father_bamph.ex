defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.FatherBamph do
  @moduledoc """
  Prontera Church priest who leads the Geoborg Family Curse quest and opens the Nameless Island
  access quest.

  ## Behavior

  - Takes Bonnie Imbullea's herb pouch, then reveals the secret of Jormungand's curse on the
    Geoborg princes and asks the player to learn more about the serpent song from Bonnie.
  - After Bonnie's report of a Red Gemstone fragment, sends the player to the secret ceremonial
    grounds, then to the Assassin Guild in Morocc to learn how to test for poison.
  - Once the princes are proven poisoned he thanks the player; on the paths that also clear
    Bonnie's name he grants base experience (90,000 in renewal, 1,600,000 in pre-renewal).
  - After the curse quest ends, he sends the player to Comodo after a missing official and,
    with a 1 in 5 chance per talk, asks them to continue the investigation in Rachel, paying
    5,000 zeny (renewal) or 1,500 zeny (pre-renewal) for the airship.
  - Each stage in between has a reminder; quest states he does not handle get no reply.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 185,
        y: 106,
        dir: 3,
        sprite: 60,
        name: "Father Bamph",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @speaker "[Father Bamph]"
  @leather_pouch 7432

  @impl true
  def on_talk(ctx) do
    curse = get_char_var(ctx, :prt_curse, 0)
    aru_monas = get_char_var(ctx, :aru_monas, 0)

    cond do
      curse == 13 -> receive_herb_pouch(ctx)
      curse == 14 -> reveal_jormungand_curse(ctx)
      curse == 15 -> recall_serpent_song(ctx)
      curse == 16 -> bonnie_song_reminder(ctx)
      curse == 17 -> hear_red_gemstone_report(ctx)
      curse in 18..21 -> ceremonial_grounds_reminder(ctx)
      curse == 22 -> send_to_assassin_guild(ctx)
      curse == 23 -> assassin_guild_reminder(ctx)
      curse == 31 -> request_first_poison_test(ctx)
      curse in [32, 33, 41, 42, 51, 52] -> poison_test_reminder(ctx)
      curse == 34 -> thank_for_proving_murder(ctx)
      curse in 35..39 and aru_monas == 0 -> lost_in_doubt(ctx)
      curse == 40 -> request_second_poison_test(ctx)
      curse in [43, 53] -> clear_bonnies_name(ctx, curse)
      curse in 44..49 and aru_monas == 0 -> bonnie_news_reminder(ctx)
      curse == 50 -> request_third_poison_test(ctx)
      curse == 60 -> hear_of_western_land(ctx)
      curse in [36, 45, 56, 61] -> nameless_island(ctx, aru_monas)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp player_speaker(ctx), do: "[#{char_name(ctx, 0)}]"

  defp receive_herb_pouch(ctx) do
    {ctx, _} =
      ctx
      |> mes(@speaker)
      |> mes("Welcome to")
      |> mes("Prontera Church.")
      |> mes("Please relax, and")
      |> mes("let your mind and")
      |> mes("spirit find rest in")
      |> mes("these hallowed halls.")
      |> next()
      |> select(["Give him the herb pouch."])

    if count_item(ctx, @leather_pouch) < 1 do
      ctx
      |> mes(player_speaker(ctx))
      |> mes("Ack!")
      |> mes("Now, where did I put")
      |> mes("that pouch with the herbs?")
      |> close()
    else
      hand_over_herb_pouch(ctx)
    end
  end

  defp hand_over_herb_pouch(ctx) do
    {ctx, _} =
      ctx
      |> mes(@speaker)
      |> mes("May I ask...")
      |> mes("Why are you giving")
      |> mes("me this pouch of herbs?")
      |> next()
      |> mes(player_speaker(ctx))
      |> mes("Well, there was this")
      |> mes("lady living on Mount")
      |> mes("Mjolnir who wanted me")
      |> mes("to give this to you. Um, she")
      |> mes("has a son named Kaanu?")
      |> next()
      |> mes(@speaker)
      |> mes("Oh, you must have met")
      |> mes("Bonnie Imbullea. It's")
      |> mes("been a long time since")
      |> mes("I've seen her. How is")
      |> mes("she doing, may I ask?")
      |> next()
      |> mes(player_speaker(ctx))
      |> mes("Oh...")
      |> mes("I guess she's fine.")
      |> mes("But she seems really...")
      |> mes("I dunno, tormented...")
      |> next()
      |> mes("[Father Biscuss]")
      |> mes("Good! If she were happy")
      |> mes("and relaxed after what she")
      |> mes("did, not even God would forgive")
      |> mes("her! She deserves to live the")
      |> mes("rest of her life in agony!")
      |> next()
      |> mes(@speaker)
      |> mes("Father Biscuss, how can")
      |> mes("you say something like that?")
      |> mes("She did her best to stop what")
      |> mes("had happened! We should pity")
      |> mes("her for the suffering she must be feeling. Where is your compassion?")
      |> next()
      |> mes("[Father Biscuss]")
      |> mes("Bah! Don't speak to me")
      |> mes("about compassion! Weren't")
      |> mes("you the one who recommended")
      |> mes("her to perform the exorcism in")
      |> mes("the first place? You didn't")
      |> mes("forget that, did you?")
      |> next()
      |> mes("[Father Bampf]")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()
      |> mes("[Father Biscuss]")
      |> mes("Hah!")
      |> next()
      |> select(["About Bonnie Imbullea"])

    pronoun = if sex(ctx) == 1, do: "him", else: "her"

    ctx
    |> mes(@speaker)
    |> mes("Well...")
    |> mes("I don't...")
    |> mes("I don't know if")
    |> mes("I should be telling ")
    |> mes("you about that incident...")
    |> next()
    |> mes("[Father Biscuss]")
    |> mes("You know what? If Bonnie")
    |> mes("sent this adventurer here")
    |> mes("for a favor, it probably means")
    |> mes("she trusts this person. Besides, we need somebody to carry out")
    |> mes("this task for us. Why not #{pronoun}?")
    |> next()
    |> mes(@speaker)
    |> mes("Your words have the ring")
    |> mes("of truth, Father Biscuss.")
    |> mes("Well then, adventurer, give")
    |> mes("me the opportunity to tell you")
    |> mes("something very important. But, you must not tell anyone else...")
    |> set_char_var(:prt_curse, 14)
    |> delitem(@leather_pouch, 1)
    |> close()
  end

  defp reveal_jormungand_curse(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("What I am about to tell")
    |> mes("you must be kept secret.")
    |> mes("Now, do you know about")
    |> mes("Jormungand, the great serpent")
    |> mes("born from the god Loki and")
    |> mes("the giantess, Angrboda?")
    |> next()
    |> mes(@speaker)
    |> mes("Jormungand was an evil")
    |> mes("beast that, after the thousand")
    |> mes("year war between the gods and")
    |> mes("demons, began to attack humans.")
    |> mes("It brought great chaos and much")
    |> mes("suffering around the world...")
    |> next()
    |> mes(@speaker)
    |> mes("Finally, the first Tristram of")
    |> mes("the Geoborg family defeated")
    |> mes("Jormungand together with 6")
    |> mes("other warriors, but only after")
    |> mes("it killed his beloved father.")
    |> next()
    |> mes(@speaker)
    |> mes("Tristram would become the")
    |> mes("first king of the Rune-Midgarts")
    |> mes("Kingdom, but his family would")
    |> mes("suffer from the curse placed")
    |> mes("by Jormungand before its defeat. ")
    |> next()
    |> mes(@speaker)
    |> mes("To this day...")
    |> mes("^FF0000Every first prince of")
    |> mes("the Geoborg family dies")
    |> mes("at a young age^000000. That is")
    |> mes("Jormungand's curse and")
    |> mes("the royal family's secret.")
    |> emotion(:huk, playerattached(ctx))
    |> next()
    |> mes(player_speaker(ctx))
    |> mes("What...?!")
    |> mes("Is this really true?!")
    |> mes("Isn't there any way to")
    |> mes("counter this horrible curse?!")
    |> next()
    |> mes(@speaker)
    |> mes("Please lower your voice.")
    |> mes("Yes, it's a shame that the")
    |> mes("royal family must suffer like")
    |> mes("this. But all the exorcisms")
    |> mes("that have been attempted")
    |> mes("over the years have failed...")
    |> next()
    |> mes(@speaker)
    |> mes("Although the situation")
    |> mes("appeared hopeless, King")
    |> mes("Tristram III tried once again to exorcise the curse. Following")
    |> mes("his orders, the greatest priests and exorcists were all summoned.")
    |> next()
    |> mes(@speaker)
    |> mes("A series of tests was")
    |> mes("performed to select the")
    |> mes("best priests and exorcists")
    |> mes("to remove this curse. In the end, ^3131FFBonnie Imbullea^000000 was chosen to")
    |> mes("lead the exorcism ceremony.")
    |> next()
    |> mes(player_speaker(ctx))
    |> mes("Wait, but you mentioned")
    |> mes("samething about an accident.")
    |> mes("Does that mean that she failed")
    |> mes("in performing the exorcism?")
    |> next()
    |> mes(@speaker)
    |> mes("Yes, unfortunately.")
    |> mes("After the priests and")
    |> mes("exorcists gathered in the")
    |> mes("secret ceremonial grounds,")
    |> mes("three princes were killed")
    |> mes("instead of just the first.")
    |> next()
    |> mes("[Father Biscuss]")
    |> mes("Although we all swore to")
    |> mes("keep that incident a secret,")
    |> mes("Bonnie Imbullea took full")
    |> mes("responsibility for the deaths.")
    |> mes("That is why she is in self")
    |> mes("imposed exile from the kingdom.")
    |> next()
    |> mes(player_speaker(ctx))
    |> mes("What...?")
    |> mes("That's...")
    |> mes("That's crazy!")
    |> next()
    |> mes("[Father Biscuss]")
    |> mes("I know that this")
    |> mes("is a very long story,")
    |> mes("and that it's a little")
    |> mes("complicated. Please")
    |> mes("listen to what we have")
    |> mes("to ask from here on...")
    |> emotion(:think)
    |> set_char_var(:prt_curse, 15)
    |> close()
  end

  defp recall_serpent_song(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Now, you should know that")
    |> mes("all of the princes that were")
    |> mes("killed that day bore strange")
    |> mes("looking marks on their bodies.")
    |> mes("It almost looked as if they")
    |> mes("were growing snake scales.")
    |> emotion(:surprise, playerattached(ctx))
    |> next()
    |> mes(player_speaker(ctx))
    |> mes("Wait, they grew snake")
    |> mes("scales? That sounds just")
    |> mes("like one of the versions of")
    |> mes("this song I'm investigating.")
    |> mes("I think it was the song about the Rune-Midgarts Kingdom's origin.")
    |> next()
    |> mes(@speaker)
    |> mes("Wait, that song?")
    |> mes("Hm, I don't see how")
    |> mes("it's related. Let's see")
    |> mes("now, how did it go?")
    |> mes("Rainbows... Eagles...")
    |> mes("Ah! Now I remember!")
    |> next()
    |> mes(@speaker)
    |> mes("The great serpent")
    |> mes("swallowed the sea.")
    |> mes("The eagle of the rainbow")
    |> mes("swallowed the serpent.")
    |> mes("Then the eagle built its nest.")
    |> mes("A nest upon the swallowed sea.")
    |> next()
    |> mes(player_speaker(ctx))
    |> mes("Hmm...")
    |> mes("Well, I heard a")
    |> mes("different version")
    |> mes("of the same song.")
    |> mes("It goes like...")
    |> next()
    |> mes(player_speaker(ctx))
    |> mes("The great serpent")
    |> mes("swallowed the sea.")
    |> mes("The eagle of the rainbow")
    |> mes("swallowed the serpent.")
    |> mes("Then snake scales grew on")
    |> mes("the eagle, and it slowly died.")
    |> next()
    |> mes(@speaker)
    |> mes("Oh, my. I learned the song")
    |> mes("when I was a young boy from")
    |> mes("my father. However, your version seems to reveal the secret curse")
    |> mes("of the Geoborgs. Please tell me, where did you hear that song?")
    |> next()
    |> mes(player_speaker(ctx))
    |> mes("Well, I first heard this")
    |> mes("version from a historian,")
    |> mes("and then I found out that")
    |> mes("Bonnie Imbullea knows it as")
    |> mes("well. Um, is there a problem?")
    |> next()
    |> mes(@speaker)
    |> mes("If those song lyrics are")
    |> mes("spread, the secret of the")
    |> mes("royal family curse could be")
    |> mes("revealed to the public. Would")
    |> mes("you please help us by speaking")
    |> mes("to Bonnie Imbullea once again?")
    |> next()
    |> mes(@speaker)
    |> mes("If you can, please try to")
    |> mes("see if you can learn of any")
    |> mes("connection between the curse")
    |> mes("and the song, or if she can")
    |> mes("remember anything that happened")
    |> mes("after the exorcism failed...")
    |> set_char_var(:prt_curse, 16)
    |> close()
  end

  defp bonnie_song_reminder(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Please visit Bonnie")
    |> mes("Imbullea in Mount Mjolnir")
    |> mes("to see if you can learn more")
    |> mes("about that song, or about what")
    |> mes("happened after the attempted exorcism of the Jormungand curse.")
    |> close()
  end

  defp hear_red_gemstone_report(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Ah, have you spoken")
    |> mes("to Bonnie Imbullea?")
    |> mes("Please tell me if you")
    |> mes("have learned anything new.")
    |> next()
    |> mes("^3355FFYou related everything")
    |> mes("that Bonnie Imbullea spoke")
    |> mes("about, including the discovery")
    |> mes("of a fragment of Red Gemstone")
    |> mes("in the secret ceremonial grounds. ")
    |> next()
    |> mes(@speaker)
    |> mes("Red Gemstone? There's")
    |> mes("no reason for that to be in")
    |> mes("a holy place. Hmm. There's")
    |> mes("more to this case than meets")
    |> mes("the eye. We better investigate")
    |> mes("the truth, starting now.")
    |> next()
    |> mes(@speaker)
    |> mes("Come with me, adventurer,")
    |> mes("to the secret ceremonial")
    |> mes("grounds for the royal family.")
    |> mes("Just use the switch hidden")
    |> mes("within the bookshelf and")
    |> mes("I will meet you there.")
    |> set_char_var(:prt_curse, 18)
    |> close()
  end

  defp ceremonial_grounds_reminder(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Come with me to the")
    |> mes("secret ceremonial grounds")
    |> mes("so that we can investigate")
    |> mes("the possibility of sabotage")
    |> mes("with the exorcism that")
    |> mes("Bonnie Imbullea performed.")
    |> next()
    |> mes(@speaker)
    |> mes("There is a hidden switch")
    |> mes("in the bookshelf that you")
    |> mes("can use to transport yourself")
    |> mes("there. Go, and I will meet")
    |> mes("you in the ceremonial grounds.")
    |> close()
  end

  defp send_to_assassin_guild(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("This is a matter of grave")
    |> mes("importance, but we can't")
    |> mes("alert the royal family yet and")
    |> mes("cause a panic. It would be")
    |> mes("best to fully investigate this")
    |> mes("first and collect proof.")
    |> next()
    |> mes(@speaker)
    |> mes("Brave adventurer, would")
    |> mes("you please visit the Assassin")
    |> mes("Guild in Morocc and see if you")
    |> mes("can learn anything about how")
    |> mes("we can verify whether poison")
    |> mes("was used to kill the princes?")
    |> set_char_var(:prt_curse, 23)
    |> close()
  end

  defp assassin_guild_reminder(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Please see if you can")
    |> mes("learn anything about testing")
    |> mes("for the use of poison from")
    |> mes("a member of the Assassin")
    |> mes("Guild in Morocc.")
    |> close()
  end

  defp request_first_poison_test(ctx) do
    ctx
    |> poison_report("^3355FFYou relate all of the")
    |> mes(@speaker)
    |> mes("Ah, I see. Then, would")
    |> mes("you please bring 1 Yellow")
    |> mes("Gemstone and 1 Green Potion")
    |> poison_test_meeting(32)
  end

  defp request_second_poison_test(ctx) do
    ctx
    |> poison_report("^3355FFYou relate all of the")
    |> mes(@speaker)
    |> mes("Ah, I see. Then, would")
    |> mes("you please bring^3131FF 1 Yellow")
    |> mes("Gemstone^000000 and ^3131FF1 Green Potion^000000")
    |> poison_test_meeting(41)
  end

  defp request_third_poison_test(ctx) do
    ctx
    |> poison_report("You relate all of the")
    |> mes(@speaker)
    |> mes("Ah, I see. Then, would")
    |> mes("you please bring ^3131FF1 Yellow")
    |> mes("Gemstone^000000 and ^3131FF1 Green Potion^000000")
    |> poison_test_meeting(51)
  end

  defp poison_report(ctx, relate_line) do
    ctx
    |> mes(@speaker)
    |> mes("Ah, you've returned~")
    |> mes("Have you managed to learn")
    |> mes("anything about poison from")
    |> mes("the Assassin Guild? I know")
    |> mes("their members must be")
    |> mes("very difficult to find...")
    |> next()
    |> mes(relate_line)
    |> mes("information you learned")
    |> mes("about poison to Father Bamph,")
    |> mes("including the method to test")
    |> mes("for the use of poison in murder. ")
    |> next()
  end

  defp poison_test_meeting(ctx, next_stage) do
    ctx
    |> mes("to the secret ceremonial grounds as soon as you can? I will wait")
    |> mes("over there for you once again.")
    |> set_char_var(:prt_curse, next_stage)
    |> close()
  end

  defp poison_test_reminder(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("You can use the hidden")
    |> mes("switch in the bookshelf to")
    |> mes("enter the secret ceremonial")
    |> mes("grounds. Don't forget that we")
    |> mes(
      "need^3131FF 1 Yellow Gemstone^000000 and ^3131FF1 Green Potion^000000 to test for poison."
    )
    |> close()
  end

  defp thank_for_proving_murder(ctx) do
    ctx
    |> princes_were_murdered()
    |> keep_the_secret()
    |> set_char_var(:prt_curse, 35)
    |> close()
  end

  defp clear_bonnies_name(ctx, curse) do
    next_stage = if curse == 43, do: 44, else: 54
    base_exp = if Rathena.truthy?(checkre(ctx, 3)), do: 90_000, else: 1_600_000

    ctx
    |> princes_were_murdered()
    |> mes(@speaker)
    |> mes("Oh, and would you please")
    |> mes("inform ^3131FFBonnie Imbullea^000000 that")
    |> mes("the deaths of the princes were")
    |> mes("not her fault? I'm sure that news would bring her great relief")
    |> mes("from her burden of guilt...")
    |> next()
    |> keep_the_secret()
    |> set_char_var(:prt_curse, next_stage)
    |> getexp(base_exp, 0)
    |> close()
  end

  defp princes_were_murdered(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("I can't believe it!")
    |> mes("If poison was used, then")
    |> mes("the second and third princes")
    |> mes("were murdered! Unbelievable...")
    |> mes("How can anyone kill children?")
    |> next()
    |> mes(@speaker)
    |> mes("At the very least, we now")
    |> mes("know that their deaths were")
    |> mes("not Bonnie Imbullea's fault.")
    |> mes("Now I must discuss with Father")
    |> mes("Biscuss and decide how to tell")
    |> mes("the royal family about this...")
    |> next()
  end

  defp keep_the_secret(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Once again, let me remind")
    |> mes("you that everything that has")
    |> mes("transpired here must be kept")
    |> mes("secret. The public cannot know")
    |> mes("of Jormungand's curse! It would cause political turmoil and chaos!")
    |> next()
    |> mes(@speaker)
    |> mes("Still, that does not mean")
    |> mes("that I cannot personally thank")
    |> mes("you for all of your help. I'm very grateful for what you have done,")
    |> mes("adventurer. May safety accompany you on all of your journeys.")
  end

  defp lost_in_doubt(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("I'm at a loss at what")
    |> mes("to do. Sometimes, even")
    |> mes("I have doubts and believe")
    |> mes("that Odin has abandoned us...")
    |> close()
  end

  defp bonnie_news_reminder(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Have you spoken to")
    |> mes("Bonnie Imbullea yet?")
    |> mes("Try not to worry about the")
    |> mes("news about the princes'")
    |> mes("murder. Father Biscuss")
    |> mes("and I will handle it.")
    |> close()
  end

  defp hear_of_western_land(ctx) do
    {ctx, _} =
      ctx
      |> mes(@speaker)
      |> mes("Oh, #{char_name(ctx, 0)}~")
      |> mes("Long time, no see.")
      |> mes("Have you spoken to")
      |> mes("Bonnie yet? Ah, and")
      |> mes("how may I help you today?")
      |> next()
      |> mes("^3355FFYou tell Father Bamph")
      |> mes("that rare herbs grow in")
      |> mes("a land to the west, although")
      |> mes("you do not mention that you")
      |> mes("told Rodafrian about the curse.^000000")
      |> next()
      |> mes("[Father Biscuss]")
      |> mes("Land to the west?")
      |> mes("That place is rumored to")
      |> mes("be populated by fanatics.")
      |> mes("Father Bamph, I think they")
      |> mes("may be prime suspects for")
      |> mes("the murder of the princes...")
      |> next()
      |> mes(@speaker)
      |> mes("Well, I'll admit that it's")
      |> mes("possible, but we haven't had")
      |> mes("contact with anyone from the")
      |> mes("land to the west for so long...")
      |> mes("It's still far too early to make those kinds of assumptions.")
      |> next()
      |> select(["Land to the west?"])

    ctx
    |> mes(@speaker)
    |> mes("Not much is known about")
    |> mes("the land to the west. We")
    |> mes("did send several priests")
    |> mes("there once to spread our")
    |> mes("faith. However, they failed...")
    |> next()
    |> mes(@speaker)
    |> mes("From what I can tell,")
    |> mes("almost everyone there")
    |> mes("is a strong adherent of")
    |> mes("that region's native religion.")
    |> mes("Anyway, thank you for informing")
    |> mes("us. We'll handle it from here.")
    |> next()
    |> mes(@speaker)
    |> mes("Ah, to preserve the secrets")
    |> mes("of the royal family, I ask that")
    |> mes("you refrain from entering the")
    |> mes("secret ceremonial grounds")
    |> mes("from now on. Thanks again for your help, #{char_name(ctx, 0)}.")
    |> set_char_var(:prt_curse, 61)
    |> close()
  end

  defp nameless_island(ctx, 0) do
    ctx
    |> mes(@speaker)
    |> mes("I'm sorry, but would it")
    |> mes("be alright if we talked")
    |> mes("later? I have to handle")
    |> mes("a very important task now...")
    |> close()
  end

  defp nameless_island(ctx, 1) do
    ctx
    |> mes(@speaker)
    |> mes("Oh, I've been waiting for")
    |> mes("you, adventurer. I'm sorry")
    |> mes("for giving you such short")
    |> mes("notice, but it seems that")
    |> mes("you've grown much stronger")
    |> mes("since the last time we met.")
    |> next()
    |> mes(@speaker)
    |> mes("The Church has received")
    |> mes("a request from Prontera")
    |> mes("Palace, but we don't have")
    |> mes("the resources to handle it.")
    |> mes("I believe you'd be well suited")
    |> mes("to this task if you'll help us.")
    |> next()
    |> mes(@speaker)
    |> mes("A man of high rank suddenly")
    |> mes("disappeared a while ago.")
    |> mes("Although Prontera Palace")
    |> mes("asked us to find him, I can")
    |> mes("only tell you who he is later.")
    |> next()
    |> mes(@speaker)
    |> mes("All we know is that he was")
    |> mes("last seen in Comodo. Please")
    |> mes("speak to our informant, ^6B8E23Larjes^000000,")
    |> mes("and he will assist you in your")
    |> mes("search for the lost official.")
    |> set_char_var(:aru_monas, 2)
    |> close()
  end

  defp nameless_island(ctx, aru_monas) when aru_monas in [2, 3] do
    ctx
    |> mes(@speaker)
    |> mes("Please go to Comodo and")
    |> mes("find our informant, ^6B8E23Larjes^000000,")
    |> mes("in the Casino. He will help")
    |> mes("you in your search for the")
    |> mes("official who disappeared.")
    |> close()
  end

  defp nameless_island(ctx, 4) do
    {ctx, _} =
      ctx
      |> mes(@speaker)
      |> mes("Ah, so you found Larjes?")
      |> mes("How has your investigation of")
      |> mes("that official's disappearance")
      |> mes("progressing? I hope that he")
      |> mes("is still safe and sound")
      |> mes("when you find him.")
      |> next()
      |> select(["Tell him what Larjes said."])

    ctx
    |> mes(@speaker)
    |> mes("I see. We've detected some")
    |> mes("disquieting activity from")
    |> mes("Arunafeltz lately, but I didn't")
    |> mes("think they would make")
    |> mes("their move so soon. Hmm...")
    |> mes("Give me a moment to think.")
    |> set_char_var(:aru_monas, 5)
    |> close()
  end

  defp nameless_island(ctx, 5) do
    if Enum.random(1..5) == 4, do: offer_investigation(ctx), else: still_considering(ctx)
  end

  defp nameless_island(ctx, 6) do
    ctx
    |> mes(@speaker)
    |> mes("You might have problems")
    |> mes("in Rachel since the culture")
    |> mes("there is much different than")
    |> mes("our own. Their ways of doing")
    |> mes("things, their government...")
    |> mes("Everything is tied to religion.")
    |> close()
  end

  defp nameless_island(ctx, aru_monas) when aru_monas in 7..24 do
    ctx
    |> mes(@speaker)
    |> mes("Thank you so much for all")
    |> mes("of your hard work. Our agents")
    |> mes("will contact you whenever they")
    |> mes("uncover any new information.")
    |> mes("Remember that no one can")
    |> mes("know what we've been doing.")
    |> close()
  end

  defp nameless_island(ctx, aru_monas) when aru_monas in [25, 26] do
    ctx
    |> mes(@speaker)
    |> mes("Thank you for bring us such")
    |> mes("important information. With")
    |> mes("your help, we were able to")
    |> mes("clear a few unsolved cases.")
    |> mes("We expected something like")
    |> mes("this, but not this soon.")
    |> next()
    |> mes(@speaker)
    |> mes("I fear that the Royal Court")
    |> mes("has been bickering over their")
    |> mes("own selfish needs. I pray that")
    |> mes("it does not grow worse, devolve")
    |> mes("into chaos. ^666666*Sigh*^000000 We'll see...")
    |> close()
  end

  defp nameless_island(ctx, _aru_monas) do
    ctx
    |> mes(@speaker)
    |> mes("It's upsetting to me that")
    |> mes("Arunafeltz has been so quiet")
    |> mes("lately. You know the expression")
    |> mes("about there being a quiet lull")
    |> mes("before a raging storm, right?")
    |> close()
  end

  defp offer_investigation(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("Well, I've considered all")
      |> mes("possible scenarios. I think")
      |> mes("it would work best if you")
      |> mes("continue your investigation")
      |> mes("on our behalf. That is, if")
      |> mes("you're willing to do it.")
      |> next()
      |> mes(@speaker)
      |> mes("We don't want to provoke")
      |> mes("an international conflict")
      |> mes("with our official involvement,")
      |> mes("but I also can't force you to")
      |> mes("work for us. Whether you")
      |> mes("can help is your choice.")
      |> next()
      |> select(["Let me think about it.", "Of course, I'll help."])

    case choice do
      1 ->
        ctx
        |> mes(@speaker)
        |> mes("I hope that you decide")
        |> mes("to help us. The safety of")
        |> mes("our nation depends on the")
        |> mes("success of this investigation.")
        |> mes("We could really use your help.")
        |> close()

      _ ->
        accept_investigation(ctx)
    end
  end

  defp accept_investigation(ctx) do
    airship_fee = if Rathena.truthy?(checkre(ctx, 0)), do: 5000, else: 1500

    ctx
    |> mes(@speaker)
    |> mes("Thank you. I'm glad to hear")
    |> mes("that you'll help us. You may")
    |> mes("take the airship in Izlude to")
    |> mes("travel to Arunafeltz, where you")
    |> mes("must continue your investigation.")
    |> next()
    |> mes(@speaker)
    |> mes("I believe that you should")
    |> mes("be able to learn more if you")
    |> mes("investigate the city of ^9370DBRachel^000000.")
    |> mes("Please accept this money")
    |> mes("to cover your Airship fee.")
    |> mes("Thank you, and good luck.")
    |> set_char_var(:aru_monas, 6)
    |> credit_zeny(airship_fee)
    |> close()
  end

  defp still_considering(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Hmm... What's the best way")
    |> mes("for us to handle this? Let")
    |> mes("me think about our options.")
    |> mes("We can--no. That wouldn't")
    |> mes("work. This will be difficult.")
    |> close()
  end
end
