defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.MerchantSkills.Necko do
  @moduledoc """
  Necko, a loud shopkeeper in Alberta, teaches the Crazy Uproar quest skill.

  ## Behavior

  - Laughs loudly at players who walk near him.
  - Tells merchants below Job Level 15 to come back later.
  - Teaches Crazy Uproar for 7 Pearls, 1 Banana Juice, and 50 Mushroom Spores to merchant-line
    characters at Job Level 15 or higher, or to any Blacksmith or Alchemist.
  - Otherwise explains the skill and its materials to merchant-line characters, and tells
    everyone else his store is closed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - Silentdragon
    - IVBela
    - DracoRPG
    - L0ne_W0lf
    - Masao
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 83,
        y: 96,
        dir: 5,
        sprite: 98,
        name: "Necko",
        scope: :shared,
        trigger: {7, 7}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @crazy_uproar 155
  @pearl 722
  @banana_juice 532
  @mushroom_spore 921

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> mes("[!?]")
    |> mes("Muahahahahahahahahahahahaha!!")
    |> mes("Pukakakakakakakakakakakakaka!")
    |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:merchant) -> store_closed(ctx)
      getskilllv(ctx, @crazy_uproar) == 1 -> reunion(ctx)
      novice_merchant?(ctx) -> come_back_later(ctx)
      qualified?(ctx) -> offer_skill(ctx)
      true -> explain_quest(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp novice_merchant?(ctx) do
    job_level(ctx) < 15 and Rathena.job_id(class(ctx)) == Rathena.job_id(:merchant)
  end

  defp qualified?(ctx) do
    count_item(ctx, @pearl) > 6 and count_item(ctx, @banana_juice) > 0 and
      count_item(ctx, @mushroom_spore) > 49 and
      (job_level(ctx) >= 15 or
         (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:blacksmith) or
            Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist)))
  end

  defp reunion(ctx) do
    ctx
    |> mes("[Necko]")
    |> mes("I'm sorry. Necko's store is...")
    |> mes("Oh? Who's this?")
    |> mes("Pukakakakakakakakakaka!!!")
    |> mes("Long time no see!")
    |> mes("How are you?")
    |> mes("Nice to see you again!!")
    |> mes("Anything new?")
    |> mes("Wow~ I'm so glad to see you!")
    |> mes("You! Stop by once in a while!")
    |> mes("I might forget what you look like!")
    |> mes("Pukakakakakakakakaka!!!")
    |> mes("Very very nice to see you!!")
    |> mes("It's so nice to see you like this!")
    |> mes("Come to Alberta often!")
    |> mes("Killing two birds with one stone!!")
    |> mes("I get to see you, and shout also!!")
    |> mes("How much better can it get!!!")
    |> mes("Keuhahahahahahahaha!!")
    |> mes("Pukakakakakakakakakaka!!!")
    |> mes("Ppyakikakikakakakakakakaka!!")
    |> close()
  end

  defp come_back_later(ctx) do
    ctx
    |> mes("[Necko]")
    |> mes("Oh, did you come because")
    |> mes("you are infatuated with my voice?")
    |> mes("My voice is loud, isn't it!")
    |> mes("considering you can hear it from a distance.")
    |> mes("And also.")
    |> mes("(looks around)")
    |> next()
    |> mes("[Necko]")
    |> mes("My voice isn't just loud!")
    |> mes("!")
    |> mes("Once you are about a level 15 merchant")
    |> mes("I will tell you the secret!")
    |> mes("Then, come again!!!")
    |> next()
    |> mes("[Necko]")
    |> mes("Uahahahahahahahahahahahaha!")
    |> mes("Kyukwakakakakakakakakakaka!")
    |> close()
  end

  defp offer_skill(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Necko]")
      |> mes("Oh! You!")
      |> mes("You are qualified to learn how to shout!")
      |> mes("Learn how to shout with my help.")
      |> mes("Would you like to learn Crazy Uproar?")
      |> next()
      |> select(["Yes!!!!", "No.", "What is that?"])

    case choice do
      1 -> teach(ctx)
      2 -> ctx |> mes("[Necko]") |> mes("Eh... ok.") |> mes("Pooooh...") |> close()
      3 -> describe_skill(ctx)
      _ -> explain_quest(ctx)
    end
  end

  defp teach(ctx) do
    ctx
    |> mes("[Necko]")
    |> mes("Ahahahahaha!! Good!!!")
    |> mes("That's the spirit!")
    |> mes("Here we go!")
    |> next()
    |> delitem(@pearl, 7)
    |> delitem(@banana_juice, 1)
    |> delitem(@mushroom_spore, 50)
    |> skill(@crazy_uproar, 1, :permanent)
    |> mes("[Necko]")
    |> mes("You have learned Crazy Uproar!!")
    |> mes("Shout as much as you wish!")
    |> mes("Hahahahahahaha!")
    |> close()
  end

  defp describe_skill(ctx) do
    ctx
    |> mes("[Necko]")
    |> mes("Crazy Uproar uses your loud voice")
    |> mes("to boost battle spirit")
    |> mes("With 8 SP, you get an additional")
    |> mes("4 STR for 5 minutes!!!!!")
    |> mes("If you use it repeatedly")
    |> mes("it is 5 minutes from that point on.")
    |> next()
    |> mes("[Necko]")
    |> mes("Stay casual in everyday life,")
    |> mes("and when you need to fight")
    |> mes("it will gather your spirit.")
    |> mes("Very useful, I must say!!!!")
    |> close()
  end

  defp explain_quest(ctx) do
    ctx
    |> mes("[Necko]")
    |> mes("Oh, were you charmed ")
    |> mes("by my voice?")
    |> mes("Indeed, my voice is loud!")
    |> mes("You can hear it from so far away.")
    |> mes("And also.")
    |> mes("(looks around)")
    |> next()
    |> mes("[Necko]")
    |> mes("My voice isn't JUST loud!")
    |> mes("I have learned the skill")
    |> mes("that lets me shout..")
    |> mes("The Crazy Uproar skill!")
    |> next()
    |> mes("[Necko]")
    |> mes("Crazy Uproar uses your loud voice")
    |> mes("to boost battle spirit")
    |> mes("With 8 sp, you get an additional")
    |> mes("4 STR for 5 minutes!!!!!")
    |> mes("If you use it repeatedly")
    |> mes("it is 5 minutes from that point.")
    |> next()
    |> mes("[Necko]")
    |> mes("Stay casual in everyday life,")
    |> mes("but shout to gather more")
    |> mes("strength when you fight.")
    |> mes("It is very useful!!!!")
    |> mes("To learn this skill, you first need")
    |> mes("to learn the essentials of sound!!!")
    |> next()
    |> mes("[Necko]")
    |> mes("You can learn this in Payon")
    |> mes("from a singer with just a loud voice")
    |> mes("You can take lessons from him!")
    |> next()
    |> mes("[Necko]")
    |> mes("But that person died!")
    |> mes("So you can't learn it anymore!")
    |> mes("Hahahahahahahaha!!!!")
    |> mes("..............................")
    |> mes("...Aww you look disappointed?")
    |> mes("Do you want to learn Crazy Uproar?")
    |> next()
    |> mes("[Necko]")
    |> mes("Hmm... Shall I teach you?")
    |> mes("If you really want it, that is.")
    |> mes("First, I must scorch the vocal cords.")
    |> mes("There are some things needed to do so.")
    |> next()
    |> mes("[Necko]")
    |> mes("7 Pearls, 1 bottle of Banana Juice,")
    |> mes("and 50 mushroom spores!")
    |> mes("Then I'll scorch your vocal chord!")
    |> next()
    |> mes("[Necko]")
    |> mes("See you when you are ready!")
    |> mes("I shall prepare my throat for then as well!!")
    |> mes("Bboowuuuuuuuuuuuuuuuuh~~~!!")
    |> close()
  end

  defp store_closed(ctx) do
    ctx
    |> mes("[Necko]")
    |> mes("Necko's store is closed right now.")
    |> mes("come again later. Hehe~")
    |> close()
  end
end
