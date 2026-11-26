defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Friar do
  @moduledoc """
  Lania, a friar in Payon, tells the tale of Sleipnir's birth during the Sleipnir Seal quest.

  ## Behavior

  - Outside the Sleipnir seal phase, or on a route that does not lead to her, she talks about
    training.
  - On the right route and stage she can tell the long story of Sleipnir; the player may stop at
    each pause, and hearing it to the end advances the quest.
  - Once the story has been told, she only wishes the player well.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
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
        x: 79,
        y: 171,
        dir: 4,
        sprite: 95,
        name: "Friar",
        scope: :shared,
        unique_name: "Friar#G5"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        talk_about_training(ctx)

      get_char_var(ctx, :god_sl_1, 0) not in [21, 32, 43, 14] ->
        talk_about_training(ctx)

      get_char_var(ctx, :god_sl_2, 0) not in [1, 3] ->
        ctx
        |> mes("[Lania]")
        |> mes(
          "I told you everything I know. Hopefully, I was of some help to you. Please treat others with the same generosity and kindness."
        )
        |> close()

      true ->
        greet(ctx)
    end
  end

  defp talk_about_training(ctx) do
    ctx
    |> mes("[Lania]")
    |> mes("Training isn't limited to just physical and mental conditioning.")
    |> next()
    |> mes("[Lania]")
    |> mes(
      "The way you lead your life and interact with other people can also be considered part of your training."
    )
    |> next()
    |> mes("[Lania]")
    |> mes(
      "Everyone will learn and benefit differently, depending on how they live their day to day lives."
    )
    |> close()
  end

  defp greet(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lania]")
      |> mes(
        "No matter how old the stories are, you can always find good advice in folk tales and legends."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Despite the passing of time and mankind's progression, certain fundamentals of life are timeless and will never change."
      )
      |> next()
      |> select(["Umm...", "I see."])

    case choice do
      1 ->
        offer_help(ctx)

      2 ->
        ctx
        |> mes("[Lania]")
        |> mes("In times of agony, please reflect on your past to help you find a solution.")
        |> next()
        |> mes("[Lania]")
        |> mes(
          "Like the old myths and legends, your experiences are stories from which you can learn valuable lessons."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lania]")
      |> mes("Hmm...?")
      |> mes("Do you need")
      |> mes("anything from me?")
      |> mes("I will try to help")
      |> mes("you as much as I can.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "I believe that it's no use having ability or power unless you use that power for the right purposes."
      )
      |> next()
      |> select(["Oh no, that's okay.", "Sleipnir's story."])

    case choice do
      1 ->
        ctx
        |> mes("[Lania]")
        |> mes("I must have")
        |> mes("misunderstood me.")
        |> mes("However, feel free")
        |> mes("to ask me for help")
        |> mes("if you ever need it.")
        |> next()
        |> mes("[Lania]")
        |> mes(
          "I consider helping others as special training for my spiritual improvement. I hope that you will act with kindness and generosity towards others as well."
        )
        |> close()

      2 ->
        tell_rampart_deal(ctx)

      _ ->
        ctx
    end
  end

  defp tell_rampart_deal(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lania]")
      |> mes("Ah, I see.")
      |> mes(
        "I can tell you what I know about Sleipnir. Let's see now if I can remember everything about it."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("Ah yes.")
      |> mes("I remember it now.")
      |> mes("Yes, Sleipnir was the")
      |> mes("name of Odin's stallion.")
      |> next()
      |> mes("[Lania]")
      |> mes("In the world of")
      |> mes("gods, there were")
      |> mes("three legendary stallions: Sleipnir, Svadilfari and Gullfaxi.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Gullfaxi was owned by Hrungnir, the king of the giants. Svadilfari, the stallion that sired Sleipnir, was also owned by a giant."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Okay, now let's talk about how 'Sleipnir' was born. This story gives us a glimpse of the fallibility of gods and giants."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "In Asgard, the realm of the gods, there was a huge protective rampart that was almost completely destroyed in a recent war."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("However...")
      |> mes("Gods being gods,")
      |> mes("they were not eager")
      |> mes("to rebuild the walls")
      |> mes("themselves.")
      |> next()
      |> mes("[Lania]")
      |> mes("One day, a very")
      |> mes("skinny man rode on")
      |> mes(
        "a dark horse and offered to rebuild, and even improve, the rampart protecting Asgard."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "His offer was tempting to the gods, who needed every protection from their enemies."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("This man promised to rebuild")
      |> mes(
        "the Asgardian rampart in only 18 months, but in return he wanted the goddess Freya as his wife, as well as ownership of the sun and the moon."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Now, this price was unreasonable for the gods to pay. The Asgardians were all insulted and angered by the stranger's demands. Still, they did want their rampart to be rebuilt."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(".....")
      |> mes("Are you bored?")
      |> mes("If you are, we can")
      |> mes("finish this")
      |> mes("story later.")
      |> next()
      |> select(["Yeah, let's finish this later.", "No, please go ahead."])

    case choice do
      1 ->
        ctx
        |> mes("[Lania]")
        |> mes(
          "I understand that my story was not that interesting. But I will try my best to entertain you next time. Please travel in safety."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Lania]")
        |> mes("Oh alright.")
        |> mes("Then let me continue.")
        |> next()
        |> tell_lokis_plan()

      _ ->
        ctx
    end
  end

  defp tell_lokis_plan(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lania]")
      |> mes(
        "The gods were furious with the stranger's ridiculous demands. However, Loki proposed to Odin"
      )
      |> mes("that they should let the stranger rebuild their defensive walls.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Loki suggested that if the stranger could complete most of the rampart renovation, but later than as agreed, the gods would not be obligated to pay the stranger any price."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Odin decided to follow Loki's advice, and told the stranger that the wall must be repaired in 6 months, instead of 18 months as the stranger had proposed. He could receive help from no man."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "In return, the stranger would be paid as he had asked if he could fulfill those conditions. Since he was just a man, it seemed impossible."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("Hmmm...")
      |> mes(
        "I know this story is quite long. Did you want to listen some more, or did you need a break?"
      )
      |> next()
      |> select([
        "Let me take down some notes first.",
        "I need a break!",
        "No, please go ahead."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Lania]")
        |> mes("Ah....")
        |> mes(
          "I understand this story is quite long. My apologies. Alright, I'll wait for you to finish writing your notes."
        )
        |> next()
        |> wait_for_notes()
        |> mes("[Lania]")
        |> mes("Okay, now")
        |> mes("where was I?")
        |> next()
        |> tell_svadilfari()

      2 ->
        ctx
        |> mes("[Lania]")
        |> mes(
          "I understand that the tale of Sleipnir is pretty long. But if you have the patience, I will try to relate this story to you another time. Farewell~"
        )
        |> close()

      3 ->
        ctx
        |> mes("[Lania]")
        |> mes("Oh good.")
        |> mes("Then please let me continue.")
        |> next()
        |> tell_svadilfari()

      _ ->
        ctx
    end
  end

  defp tell_svadilfari(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lania]")
      |> mes(
        "Now, the stranger insisted that he be able to use his horse to help him do this reconstruction work. Since the horse was rather plain and simple looking, Odin agreed."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("Odin didn't think")
      |> mes("twice about his")
      |> mes(
        "request, and regretted this decision upon observing the stranger's first day of rebuilding the rampart."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Strangely enough, the stranger, using his horse to carry the materials, rebuilt the rampart at a speed that was inhuman."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "This upset the gods, since the stranger was actually a mighty giant in disguise. However, this did not violate their agreement,"
      )
      |> mes("so the gods could do nothing.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Although the stranger's skills were great, his horse greatly sped up the rampart reconstruction. This was the legendary magical horse, Svadilfari."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "The gods grew more anxious as the wall would soon be completed before the alloted six months were up. The Asgardians soon grew very angry with Loki."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Despite this, Loki remained calm and assured the gods that he had a plan. The gods distrusted his craftiness, and grew desperate as the stranger's work speedily progressed."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Then, the reconstruction of the rampart suddenly halted. Both the gods and the stranger were equally surprised, as the horse Svadilfari was now missing."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("The stranger would")
      |> mes("now need to continue")
      |> mes("his work by himself.")
      |> next()
      |> mes("[Lania]")
      |> mes("Hmmm...")
      |> mes("Are you still listening? If you're tired, I understand and we can")
      |> mes("stop for now.")
      |> next()
      |> select(["I'm so exhausted!", "No, please go ahead."])

    case choice do
      1 ->
        ctx
        |> mes("[Lania]")
        |> mes(
          "I know that this story might seem too long. But if you ever want to sit down and hear it again, I'll be glad to go over it again. Thank you for listening, adventurer."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Lania]")
        |> mes("Oh alright,")
        |> mes("I'll go on then.")
        |> next()
        |> tell_frost_giant()

      _ ->
        ctx
    end
  end

  defp tell_frost_giant(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lania]")
      |> mes("In their curiosity, the gods decided to investigate Savdilfari's disappearance. ")
      |> next()
      |> mes("[Lania]")
      |> mes("Surprisingly,")
      |> mes("they found that")
      |> mes("Svadilfari fell in love with a beautiful mare, which was why")
      |> mes("it did not work on the rampart.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "So when the 6 months passed, the stranger almost finished rebuilding the Asgardian walls. Only the castle gate was left untouched."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "The gods were happy to tell the stranger that they could not pay him what he requested, since he did not complete the rampart as originally agreed."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "In his rage, the stranger accused the gods of tricking him so that they would not have to pay him with the sun, the moon and the beautiful goddess Freya. Then, he revealed his true identity."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("He was a")
      |> mes("terrible frost giant,")
      |> mes("or Hrimthurs as they say.")
      |> next()
      |> mes("[Lania]")
      |> mes(".....")
      |> mes("Are you bored?")
      |> mes("If you are, we can")
      |> mes("talk about this")
      |> mes("later you know.")
      |> next()
      |> select(["I'm so bored~", "No, please go ahead."])

    case choice do
      1 ->
        ctx
        |> mes("[Lania]")
        |> mes(
          "I see. Well, stories are meant to be enjoyed and I suppose you're not in the mood to sit and listen."
        )
        |> next()
        |> mes("[Lania]")
        |> mes(
          "But if you ever do want to hear about Sleipnir, feel free to visit me once again. Have a good day~"
        )
        |> close()

      2 ->
        ctx
        |> mes("[Lania]")
        |> mes("Oh, I'm glad~")
        |> mes("Some people would")
        |> mes("actually be sleeping")
        |> mes("after listening so long~")
        |> next()
        |> tell_thors_hammer()

      _ ->
        ctx
    end
  end

  defp tell_thors_hammer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lania]")
      |> mes("Anyway...")
      |> mes("The stranger turned out")
      |> mes("to be a giant training in")
      |> mes("stone masonry. Although he was invading Asgard, the gods didn't worry.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Thor quickly killed the giant with his mighty hammer, Mjolnir, by hurling it at the giant's head, which exploded into a thousand pieces."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("As for the horse, Svadilfari, it was nowhere to be found for")
      |> mes("a long, long time.")
      |> next()
      |> mes("[Lania]")
      |> mes(".....")
      |> mes("Are you bored?")
      |> mes("If you are, let's talk")
      |> mes("about this later.")
      |> next()
      |> select([
        "Let me take down some notes.",
        "See you later.",
        "No, please go ahead."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Lania]")
        |> mes("Ah....")
        |> mes("I see that you really want to keep track of every important detail!")
        |> next()
        |> mes("[Lania]")
        |> mes("My apologies, I'll wait for you to complete your notes then.")
        |> next()
        |> wait_for_notes()
        |> resume_ending()

      2 ->
        ctx
        |> mes("[Lania]")
        |> mes(
          "Oh, I guess my story wasn't really that interesting. But if you want to listen to this story again, please come visit me again."
        )
        |> next()
        |> mes("[Lania]")
        |> mes("Okay then,")
        |> mes("travel safely~")
        |> close()

      3 ->
        resume_ending(ctx)

      _ ->
        ctx
    end
  end

  defp resume_ending(ctx) do
    ctx
    |> mes("[Lania]")
    |> mes("Okay. Hmm...")
    |> mes("Now where was I?")
    |> next()
    |> tell_sleipnirs_birth()
  end

  defp tell_sleipnirs_birth(ctx) do
    ctx =
      ctx
      |> mes("[Lania]")
      |> mes(
        "After a while, Loki, who looked tattered and worn out, brought a strange looking pony with eight legs to Asgard."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("Loki introduced the pony as 'Sleipnir' and presented it to")
      |> mes("Odin as a present.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "In actuality, Loki transformed into the mare that seduced Svadilfari so that it would no longer work on the rampart."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "So 'Sleipnir' was born from the legendary mare Svadilfari, and the god Loki who transformed himself into a horse."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "Now, stories that are spread through word of mouth might have differences in the small details, depending on who's telling the story."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("Still, the fundamental story line should not be different.")
      |> next()
      |> mes("[Lania]")
      |> mes(
        "I don't usually get to practice storytelling, and I'm not too confident of the authenticity of my version of Sleipnir's tale."
      )
      |> next()
      |> mes("[Lania]")
      |> mes(
        "But I hope you will understand that I did my best. It was the most that I could do to help you."
      )
      |> next()
      |> mes("[Lania]")
      |> mes("If you wish to listen to this story again, you're always welcome.")
      |> mes("Be safe on your adventures~")

    ctx
    |> advance_stage(get_char_var(ctx, :god_sl_2, 0))
    |> close()
  end

  defp advance_stage(ctx, 1), do: set_char_var(ctx, :god_sl_2, 2)
  defp advance_stage(ctx, 3), do: set_char_var(ctx, :god_sl_2, 4)
  defp advance_stage(ctx, _stage), do: ctx

  defp wait_for_notes(ctx) do
    {ctx, _} =
      ctx
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> mes("...............")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> mes("...............")
      |> mes("..................")
      |> next()
      |> mes("[Lania]")
      |> mes("May I continue the story now?")
      |> next()
      |> select(["Yes, please."])

    ctx
  end
end
