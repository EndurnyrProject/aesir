defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.BardSkills.YoungMan do
  @moduledoc """
  A timid young man in Prontera, terrified of Bards, who starts the Bard Pang Voice skill quest.

  ## Behavior

  - Panics when a Bard walks near or talks to him; other players only hear him fret about Bards.
  - A Bard who offers him a Tropical Sograt hears how a strange Bard in Umbala controlled his
    body; the drink is consumed, and at Job Level 40 or higher the quest begins.
  - Bards who already started or finished the quest are turned away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - DracoRPG

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/bard_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 174,
        y: 328,
        dir: 3,
        sprite: 89,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#bard_q1",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @tropical_sograt 12112

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if bard?(ctx), do: emotion(ctx, :huk), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if bard?(ctx), do: confront_bard(ctx), else: fear_bards(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp bard?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:bard)

  defp player_says(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp fear_bards(ctx) do
    ctx
    |> mes("[Timid Young Man]")
    |> mes("Oh... Oh goodness.")
    |> mes("Was that a Bard just")
    |> mes("over there? Oh, I'm so")
    |> mes("afraid of those guys!")
    |> mes("And those Minstrels")
    |> mes("are even worse!")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("Don't get me wrong, I love")
    |> mes("songs and entertainment,")
    |> mes("but you've got to understand!")
    |> mes("Some of them have powers")
    |> mes("that you wouldn't believe!")
    |> mes("I... I've seen them myself!")
    |> close()
  end

  defp confront_bard(ctx) do
    ctx =
      ctx
      |> emotion(:huk)
      |> mes("[Timid Young Man]")
      |> mes("Eh? Wwwaaaah--!")
      |> mes("Y-you're--it's-it's--")

    ctx =
      if upper(ctx) != 1,
        do: mes(ctx, "It's a freakin' Bard!"),
        else: mes(ctx, "It's a freakin' Minstrel!")

    {ctx, choice} =
      ctx
      |> mes("D-don't come any closer!")
      |> mes("I... I don't like you guys!")
      |> next()
      |> select(["Wha--? Why the heck not?", "Hey, take it easy, man."])

    if choice == 1, do: refuse_to_relax(ctx), else: hear_out(ctx)
  end

  defp stay_away(ctx) do
    ctx
    |> mes("[Timid Young Man]")
    |> mes("N-no! Don't look at me!")
    |> mes("I know what you're trying")
    |> mes("to do! Please, I haven't")
    |> mes("done anything to you!")
    |> mes("J-just s-stay away!")
    |> next()
  end

  defp refuse_to_relax(ctx) do
    ctx
    |> stay_away()
    |> player_says()
    |> mes("Um...")
    |> mes("I'm not really trying")
    |> mes("to do anything. Why")
    |> mes("don't you relax, and--")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("Relax?! Nobody believes me")
    |> mes("when I tell them how dangerous")
    |> mes("you guys are. You think you're")
    |> mes("so smug with your funny jokes")
    |> mes("and lovely songs, but I know")
    |> mes("what kind of powers you have!")
    |> close()
  end

  defp hear_out(ctx) do
    {ctx, choice} =
      ctx
      |> stay_away()
      |> select(["Offer him a drink.", "Reassure him that you're safe."])

    if choice == 1, do: offer_drink(ctx), else: reassure(ctx)
  end

  defp offer_drink(ctx) do
    ctx =
      ctx
      |> player_says()
      |> mes("Look, I don't know what")
      |> mes("you've got against me, but")
      |> mes("you really need to relax.")
      |> mes("Here, have a drink on me.")
      |> next()

    if count_item(ctx, @tropical_sograt) > 0, do: accept_drink(ctx), else: refuse_drink(ctx)
  end

  defp refuse_drink(ctx) do
    ctx
    |> mes("[Timid Young Man]")
    |> mes("Eh...?! Um, th-that's")
    |> mes("nice of y-you to offer,")
    |> mes("but I'm p-pretty picky")
    |> mes("about what I d-drink.")
    |> mes("P-plus, I don't k-know")
    |> mes("if I can t-trust you.")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("I don't think there's")
    |> mes("much that could get m-me")
    |> mes("to ch-change my m-mind!")
    |> mes("Well... Maybe if you brought")
    |> mes("my favorite drink, Tropical")
    |> mes("Sograt, I would reconsider...")
    |> close()
  end

  defp accept_drink(ctx) do
    ctx =
      ctx
      |> mes("[Timid Young Man]")
      |> mes("Oh~! Isn't that")
      |> mes("a Tropical Sograt?")
      |> mes("That's my favorite")
      |> mes("drink in all the world!")

    progress = get_char_var(ctx, :qskill_bard, 0)

    cond do
      progress == 9 -> suspect_trick(ctx)
      progress > 0 -> recognize_bard(ctx)
      true -> drink_and_relax(ctx)
    end
  end

  defp suspect_trick(ctx) do
    ctx
    |> mes("Thanks so--waitaminute.")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("This is some sort")
    |> mes("of weird trick, isn't it?")
    |> mes("And to think I almost")
    |> mes("f-f-fell for it! P-please")
    |> mes("j-just leave me alone!")
    |> close()
  end

  defp recognize_bard(ctx) do
    ctx
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("Wait, I've seen you before.")
    |> mes("And you brought me a drink")
    |> mes("just like this one. You...")
    |> mes("You d-didn't learn th-that")
    |> mes("w-w-weird skill, d-did you?")
    |> mes("Wait, no. You couldn't have...")
    |> next()
    |> player_says()
    |> mes("Oh, please~")
    |> mes("You know, I think")
    |> mes("that maybe you")
    |> mes("worry too much.")
    |> close()
  end

  defp drink_and_relax(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Timid Young Man]")
      |> mes("^333333*Gulp Gulp*^000000")
      |> mes("Ahhhh~ Oh, you don't")
      |> mes("understand how long I've")
      |> mes("been wanting this drink!")
      |> mes("It tastes so good, and")
      |> mes("now I feel sooo relaxed...")
      |> next()
      |> select(["See? I'm not dangerous at all~", "So what makes someone like me so scary?"])

    case choice do
      1 ->
        ctx
        |> mes("[Timid Young Man]")
        |> mes("Hmmm... Maybe.")
        |> mes("Maybe all of you Bards")
        |> mes("and Minstrels aren't that")
        |> mes("bad. But I can never forget")
        |> mes("what that Bard did to me...")
        |> next()
        |> recount_bungee_jump([
          "safe, and that only a few people",
          "have died by jumping. Then, he",
          "just... He gave me this intense look."
        ])

      2 ->
        ctx
        |> mes("[Timid Young Man]")
        |> mes("^333333*Sigh*^000000 Well, maybe all Bards")
        |> mes("and Minstrels aren't terrifying. But any Bard will remind me")
        |> mes("of the one that I met during my")
        |> mes("travels. Just thinking about")
        |> mes("that time gives me goosebumps.")
        |> next()
        |> recount_bungee_jump([
          "that a few people have died",
          "by jumping. Then, he just...",
          "He gave me this intense look."
        ])

      _ ->
        reassure(ctx)
    end
  end

  defp recount_bungee_jump(ctx, offended_lines) do
    ctx =
      ctx
      |> mes("[Timid Young Man]")
      |> mes("It all started when I was")
      |> mes("traveling through Umbala and")
      |> mes("met a strange Bard who was")
      |> mes("studying under the tutelage")
      |> mes("of Puchuchartan, the Utan")
      |> mes("Shaman of the village.")
      |> next()
      |> mes("[Timid Young Man]")
      |> mes("That Bard and I got along fairly well until he took me to Umbala's")
      |> mes("Bungee Jump. He insisted that I jump at least once for the ''full")
      |> mes("Umbala experience.'' I refused, seeing as they don't use bungees.")
      |> next()
      |> mes("[Timid Young Man]")
      |> mes("The Bard seemed offended")
      |> mes("and claimed it was perfectly")

    offended_lines
    |> Enum.reduce(ctx, &mes(&2, &1))
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("His eyes seemed so full")
    |> mes("of rage! I remember him")
    |> mes("mumbling something, and")
    |> mes("all of a sudden, I lost control")
    |> mes("of my body! My arms and legs")
    |> mes("were just moving on their own!")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("Before long, I found myself")
    |> mes("struggling to keep myself from")
    |> mes("leaping off that Bungee Jump.")
    |> mes("But the more I resisted, the")
    |> mes("more violently I'd flail toward")
    |> mes("the edge. It was horrible!")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("That was the most terrifying")
    |> mes("experience of my life! It was")
    |> mes("bad enough that I risked my")
    |> mes("life, but that feeling of not")
    |> mes("having any control over your")
    |> mes("body is so overwhelming!")
    |> next()
    |> player_says()
    |> mes("Wait, you're saying")
    |> mes("a Bard did this to you?")
    |> mes("I've never heard of a song")
    |> mes("or skill with that sort of effect before. That's really strange...")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("Well, I've never heard")
    |> mes("of that sort of power up")
    |> mes("until I had to experience")
    |> mes("it for myself. Oh, I can still")
    |> mes("see that evil smile of his")
    |> mes("in my nightmares...")
    |> next()
    |> mes("[Timid Young Man]")
    |> mes("Anyway, thanks for that")
    |> mes("drink, it really helped me")
    |> mes("settle my nerves. But I must")
    |> mes("warn you not to look for that")
    |> mes("strange Bard. I'm sure he's really some sort of demon or something...")
    |> next()
    |> finish_drink()
    |> close()
  end

  defp finish_drink(ctx) do
    if job_level(ctx) > 39 do
      ctx
      |> mes("[Timid Young Man]")
      |> mes("But... If you really")
      |> mes("want to attain that sort")
      |> mes("of power, I can't really")
      |> mes("stop you. Thankfully, nobody")
      |> mes("has any idea of where he is~")
      |> delitem(@tropical_sograt, 1)
      |> set_char_var(:qskill_bard, 1)
    else
      ctx
      |> mes("[Timid Young Man]")
      |> mes("Even if you could find that")
      |> mes("Bard to get him to teach you")
      |> mes("how he did that to me, I'm sure")
      |> mes("he mentioned something about")
      |> mes("being at least ^660000Job Level 40^000000 to")
      |> mes("be able to handle that power...")
      |> delitem(@tropical_sograt, 1)
    end
  end

  defp reassure(ctx) do
    ctx =
      ctx
      |> player_says()
      |> mes("Don't worry,")
      |> mes("I won't hurt you.")
      |> next()
      |> mes("[Timid Young Man]")
      |> mes("Th-that's what th-they")
      |> mes("all say, right before they")
      |> mes("get into your mind and then")
      |> mes("twist it as hard as they can!")

    if get_char_var(ctx, :qskill_bard, 0) == 9 do
      ctx |> mes("J-just don't t-touch me!") |> mes("...Ack! And stay away!") |> close()
    else
      ctx
      |> mes("E-even if you d-don't have")
      |> mes("that p-power, l-leave me alone!")
      |> close()
    end
  end
end
