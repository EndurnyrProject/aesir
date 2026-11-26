defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.ExhaustedLookingWoman do
  @moduledoc """
  A woman in exile helps investigate the royal curse.

  ## Behavior

  - Discusses her son’s song and asks the player to deliver herbs.
  - Shares her history and responds to progress in the investigation.

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
        map: "mjolnir_01",
        x: 316,
        y: 268,
        dir: 3,
        sprite: 879,
        name: "Exhausted-Looking Woman",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 do
      overweight(ctx)
    else
      talk_at_stage(ctx, get_char_var(ctx, :prt_curse, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp talk_at_stage(ctx, 11), do: overhear_song(ctx)
  defp talk_at_stage(ctx, 12), do: herb_request(ctx)
  defp talk_at_stage(ctx, stage) when stage in 13..15, do: herb_reminder(ctx)
  defp talk_at_stage(ctx, 16), do: exorcism_account(ctx)
  defp talk_at_stage(ctx, 17), do: consolation(ctx)
  defp talk_at_stage(ctx, stage) when stage in [35, 44, 54], do: good_news(ctx, stage)
  defp talk_at_stage(ctx, 36), do: prayer(ctx)
  defp talk_at_stage(ctx, 45), do: mountain_home(ctx)
  defp talk_at_stage(ctx, stage) when stage > 54, do: gratitude(ctx)
  defp talk_at_stage(ctx, _stage), do: sigh(ctx)

  defp overhear_song(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Absent-Minded Boy]")
      |> mes("The great serpent")
      |> mes("swallowed the sea.")
      |> mes("The eagle of the rainbow")
      |> mes("swallowed the serpent.")
      |> mes("Then snake scales grew on")
      |> mes("the eagle, and it slowly died.")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("Goodness...!")
      |> mes("Will you please stop")
      |> mes("singing that song?")
      |> next()
      |> mes("[Absent-Minded Boy]")
      |> mes("..................")
      |> next()
      |> mes("^3355FFThe little boy quietly")
      |> mes("stared at the woman for a")
      |> mes("little bit, and then crouched")
      |> mes("down and began petting a")
      |> mes("dog sitting next to him.^000000")
      |> next()
      |> select(["What did you just sing?", "Ignore them"])

    if choice == 1 do
      ask_about_song(ctx)
    else
      ctx |> mes("[Exhausted-Looking Woman]") |> mes("...........") |> close()
    end
  end

  defp ask_about_song(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Absent-Minded Boy]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Absent-Minded Boy]")
      |> mes("Woof-woof, have you")
      |> mes("heard this song? Mommy")
      |> mes("taught me to sing it, you")
      |> mes("know. She says it was sung")
      |> mes("by people for a long time~")
      |> next()
      |> mes("^3355FFThe boy continued speaking")
      |> mes("to the dog like an old friend,")
      |> mes("ignoring your presence and")
      |> mes("acting as if you didn't exist.^000000")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("Kaanu...")
      |> mes("What did I tell")
      |> mes("you about ignoring")
      |> mes("people's questions!")
      |> next()
      |> mes("[Kaanu]")
      |> mes(".........")
      |> mes("..................")
      |> mes("Uh oh, Woof-woof.")
      |> mes("Mommy seems upset")
      |> mes("for some reason.")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("I'm sorry, my kid is...")
      |> mes("Look, did you want to know")
      |> mes("more about that song? Try")
      |> mes("not to worry about it: it's just an old children's tune.")
      |> next()
      |> select(["Why are you here?", "May I hear the song again?"])

    if choice == 1, do: ask_why_here(ctx), else: recite_song(ctx)
  end

  defp ask_why_here(ctx) do
    ctx
    |> mes("[Exhausted-Looking Woman]")
    |> mes(".................")
    |> next()
    |> mes("^3355FFThe woman's lip tightens")
    |> mes("with shame. It's obvious")
    |> mes("that this topic makes her")
    |> mes("feel very uncomfortable.^000000")
    |> next()
    |> mes("[Kaanu]")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Kaanu]")
    |> mes("Woof-woof, do you know")
    |> mes("why Mommy is always")
    |> mes("so sad? I wish I knew")
    |> mes("why Mommy never smiles...")
    |> next()
    |> mes("[Exhausted-Looking Woman]")
    |> mes("........")
    |> set_char_var(:prt_curse, 12)
    |> close()
  end

  defp recite_song(ctx) do
    ctx
    |> mes("[Exhausted-Looking Woman]")
    |> mes("..................")
    |> next()
    |> mes("[Exhausted-Looking Woman]")
    |> mes("Okay. I can do this")
    |> mes("simple thing for you.")
    |> mes("Let me recite this song...")
    |> next()
    |> mes("[Exhausted-Looking Woman]")
    |> mes("The great serpent")
    |> mes("swallowed the sea.")
    |> mes("The eagle of the rainbow")
    |> mes("swallowed the serpent.")
    |> mes("Then snake scales grew on")
    |> mes("the eagle, and it slowly died.")
    |> set_char_var(:prt_curse, 12)
    |> close()
  end

  defp herb_request(ctx) do
    ctx =
      ctx
      |> mes("[Exhausted-Looking Woman]")
      |> mes("Not too many people")
      |> mes("come to this remote area.")
      |> mes("What brings you all the")
      |> mes("way over here, I wonder?")
      |> next()

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Actually, I'm just")
      |> mes("trying to learn the")
      |> mes("real lyrics of that")
      |> mes("song that little boy")
      |> mes("has been singing.")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes(".........")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("That song's lyrics, and")
      |> mes("its meaning, can change")
      |> mes("from person to person as")
      |> mes("time goes on. I suppose part")
      |> mes("of the reason is because it's")
      |> mes("been handed down orally...")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("It sounds like such a happy")
      |> mes("song, but it's meaning had")
      |> mes("changed for me ever since")
      |> mes("the accident had happened...")
      |> mes("It's been so long, but I don't")
      |> mes("think the pain will ever heal.")
      |> next()
      |> select(["Accident?"])

    ctx =
      ctx
      |> mes("[Exhausted-Looking Woman]")
      |> mes("I'm... I'm sorry.")
      |> mes("I don't think I can talk")
      |> mes("about it. If I try, I know I'll")
      |> mes("relive the horror. Every day")
      |> mes("is already a struggle to cope")
      |> mes("with the sins I've committed.")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("I know it's selfish, but")
      |> mes("I have a favor to ask of you.")
      |> mes("I can't really leave this area,")
      |> mes("and seldom do I receive visitors. Would you be so kind to deliver")
      |> mes("something to Prontera for me?")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("I used to live in Prontera,")
      |> mes("and ever since the accident,")
      |> mes("Father Bamph has been so very")
      |> mes("supportive of me. It's not enough to repay his kindness, but please")
      |> mes("give these herbs to him for me.")
      |> next()
      |> mes("[Exhausted-Looking Woman]")
      |> mes("You can find ^3131FFFather Bamph^000000")
      |> mes("in ^3131FFProntera Church^000000. When you ")
      |> mes("see him, please give him my")
      |> mes("warmest regards. I would do it")
      |> mes("myself, but because of what I did, I can't return to Prontera...")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("^333333(Alright then. I guess")
    |> mes("I should deliver these")
    |> mes("herbs to Prontera Church")
    |> mes("before I talk to Rodafrian.)^000000")
    |> give_item(7432, 1)
    |> set_char_var(:prt_curse, 13)
    |> close()
  end

  defp herb_reminder(ctx) do
    ctx
    |> mes("[Exhausted-Looking Woman]")
    |> mes("Father Bamph has helped")
    |> mes("me so much. Please bring")
    |> mes("that herb pouch to him in")
    |> mes("Prontera Church, and give")
    |> mes("him my warmest regards.")
    |> close()
  end

  defp exorcism_account(ctx) do
    ctx =
      ctx
      |> mes("[Bonnie Imbullea]")
      |> mes("Oh, you've come back?")
      |> mes("Were you able to deliver")
      |> mes("that pouch of herbs that")
      |> mes("I gave you to Father Bamph?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Yes, I did. Actually,")
      |> mes("Father Bamph sent me")
      |> mes("here to ask you a few")
      |> mes("things. You see, he told")
      |> mes("me all about the royal secret")
      |> mes("and, well, your exorcism.")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("Oh. I see.")
      |> mes("You must think")
      |> mes("me a monster...")
      |> mes("Those poor children")
      |> mes("are dead because of me...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("N-no! Not at all!")
      |> mes("I just wanted to ask if there")
      |> mes("was a connection between")
      |> mes("the song that Kaanu has been")
      |> mes("singing and Jormungand's curse.")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("After the exorcism failed,")
      |> mes("I should have been punished")
      |> mes("with death. But the royal family and the Prontera Church took")
      |> mes("mercy on me, and allowed")
      |> mes("me to live here in exile.")
      |> emotion(:think)
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("I began to sing this song")
      |> mes("to keep myself distracted,")
      |> mes("even if it was related to")
      |> mes("the Jormungand curse.")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("You know, now that I think")
      |> mes("about it, I do remember hearing")
      |> mes("that after the exorcism failed,")
      |> mes("a maid found a fragment of a")
      |> mes("Red Gemstone while cleaning")
      |> mes("the secret ceremonial grounds.")

    ctx =
      ctx
      |> emotion(:surprise, playerattached(ctx))
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("I always thought it")
      |> mes("was a little strange.")
      |> mes("I wanted to investigate")
      |> mes("it, but then I was discharged")
      |> mes("from the Prontera Church")
      |> mes("after my failure...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("A fragment from")
      |> mes("a Red Gemstone?")
      |> mes("Maybe... maybe it's")
      |> mes("evidence that someone")
      |> mes("sabotaged the exorcism!")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("What happened was tragic,")
      |> mes("but it would make me feel")
      |> mes("so much better if that were")
      |> mes("really the truth. Even if the")
      |> mes("exorcism was sabotaged,")
      |> mes("we can't turn back time...")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("^333333(Hmm...")
    |> mes("I better head back")
    |> mes("to Prontera Church")
    |> mes("and let Father Bamph")
    |> mes("know about this information.)^000000")
    |> set_char_var(:prt_curse, 17)
    |> close()
  end

  defp consolation(ctx) do
    ctx
    |> mes("[Bonnie Imbullea]")
    |> mes("It's really very")
    |> mes("difficult to live")
    |> mes("with this guilt.")
    |> mes("I was trained to help")
    |> mes("people, not kill them!")
    |> next()
    |> mes("^3355FFYou tried to comfort")
    |> mes("Bonnie Imbullea for a")
    |> mes("little while before you")
    |> mes("return to Prontera Church.")
    |> close()
  end

  defp good_news(ctx, stage) do
    ctx =
      ctx
      |> mes("^3355FFYou tell Bonnie Imbullea")
      |> mes("that the deaths of the princes")
      |> mes("were not her fault and that the exorcism was probably sabotaged.")
      |> mes("However, you keep specifics, like the use of poison, to yourself.^000000")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("Is that really true...?")
      |> mes("Oh, I'm so happy! I really")
      |> mes("thought I'd have to live the")
      |> mes("rest of my in seclusion with")
      |> mes("this horrible shame. Oh, thank")
      |> mes("you so much for your help!")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("Kaanu will be able to")
      |> mes("meet other kids his own")
      |> mes("age... We can finally live")
      |> mes("a normal life. How wonderful...")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("But wait...")
      |> mes("How exactly did the")
      |> mes("princes die, then?")
      |> mes("There weren't any")
      |> mes("wounds on the bodies")
      |> mes("from what I remember...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Well, um, I wouldn't know")
      |> mes("anything about that, but")
      |> mes("Father Bamph and Father")
      |> mes("Biscuss are handling the")
      |> mes("investigation, and they're")
      |> mes("doing their best to find out.")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("I see. Well, I believe in")
      |> mes("them: they're great priests,")
      |> mes("after all. Although I may be")
      |> mes("forgiven for my failure, I still fear for the royal family...")
      |> mes("All I can do for now is pray.")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("Anyway, I promise that")
      |> mes("I won't reveal what I know")
      |> mes("about this incident to the")
      |> mes("public. And if you ever come")
      |> mes("by the mountain again, I hope")
      |> mes("you stop by to visit us.")
      |> next()
      |> mes("[Bonnie Imbullea]")
      |> mes("You don't understand")
      |> mes("how much the news you've")
      |> mes("brought really means to me.")
      |> mes("I can finally free myself from")
      |> mes("this burdensome guilt...")
      |> mes("Thank you, kind adventurer~")

    ctx =
      case stage do
        35 ->
          set_char_var(ctx, :prt_curse, 36)

        44 ->
          set_char_var(ctx, :prt_curse, 45)

        54 ->
          ctx
          |> next()
          |> mes("^3355FFNow, you can return to")
          |> mes("Rodafrian, the historian")
          |> mes("stationed in Morocc.^000000")
          |> set_char_var(:prt_curse, 55)
      end

    close(ctx)
  end

  defp prayer(ctx) do
    ctx
    |> mes("[Bonnie Imbullea]")
    |> mes("By your grace and mercy,")
    |> mes("please pity the poor souls")
    |> mes("and protect the royal family...")
    |> mes("Bless us with your light and")
    |> mes("may your wisdom guide us...")
    |> close()
  end

  defp mountain_home(ctx) do
    ctx
    |> mes("[Bonnie Imbullea]")
    |> mes("I guess we've gotten")
    |> mes("too used to the peace")
    |> mes("and serenity of Mount")
    |> mes("Mjolnir. It won't be easy")
    |> mes("to leave, even if we're welcome to return to Prontera...")
    |> close()
  end

  defp gratitude(ctx) do
    ctx
    |> mes("[Bonnie Imbullea]")
    |> mes("Thank you so much")
    |> mes("for helping out in the")
    |> mes("investigation of the")
    |> mes("princes. I'd never know")
    |> mes("happiness again if it")
    |> mes("weren't for your efforts.")
    |> close()
  end

  defp sigh(ctx) do
    ctx
    |> mes("[Bonnie Imbullea]")
    |> mes("^333333*Sigh...*^000000")
    |> close()
  end
end
