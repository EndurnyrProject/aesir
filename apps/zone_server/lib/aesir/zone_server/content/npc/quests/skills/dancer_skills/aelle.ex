defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.DancerSkills.Aelle do
  @moduledoc """
  Aelle, Canell's hard-drinking sister in the Prontera Church, who gives Dancers the drunken wink
  lesson of the Charming Wink skill quest.

  ## Behavior

  - Tries to sell illegal warps until the church pastor interrupts her.
  - A Dancer sent by Canell is asked for alcohol, an Apple, 3 Bananas, 5 Well-Baked Cookies and
    a set of China.
  - Consumes the food, gets drunk mid-lesson, pummels the Dancer, then sends her back to Canell
    and warps her out of the church.
  - Admires a Dancer who has finished the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - Yommy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/dancer_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 183,
        y: 333,
        dir: 1,
        sprite: 79,
        name: "Aelle",
        scope: :shared,
        unique_name: "Aelle#qsk_dan02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @alcohol 970
  @apple 512
  @banana 513
  @well_baked_cookie 538
  @china 736

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:dancer),
      do: dancer_visit(ctx),
      else: pastor_interrupts(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp player_says(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp dancer_visit(ctx) do
    step = get_char_var(ctx, :DANCER_SK, 0)

    cond do
      step == 3 -> meet_sister(ctx)
      step == 4 -> ask_for_food(ctx)
      step == 5 -> check_food(ctx)
      step == 6 -> fall_asleep(ctx)
      step > 6 and step < 8 -> still_asleep(ctx)
      step > 8 -> sober_up(ctx)
      true -> pastor_interrupts(ctx)
    end
  end

  defp warp_pitch(ctx) do
    ctx
    |> mes("[Aelle]")
    |> mes("Pssst, hey! I got")
    |> mes("some cheap, but slightly")
    |> mes("illegal, warps to the Orc")
    |> mes("Dungeon, Glast Heim")
    |> mes("and the Dead Pit. So")
    |> mes("you want in on this?")
    |> next()
  end

  defp food_order(ctx) do
    ctx
    |> mes("[Aelle]")
    |> mes("Soooo, I wanna eat")
    |> mes("^FF00001 Apple^000000, ^FF00003 Bananas^000000 and")
    |> mes("^FF00005 Well-Baked Cookies^000000. Ah,")
    |> mes("make sure you bring ^FF0000China^000000")
    |> mes("to serve them on, and don't")
    |> mes("forget the ^FF0000Alcohol^000000, okay?")
  end

  defp pastor_interrupts(ctx) do
    ctx
    |> warp_pitch()
    |> mes("[??????]")
    |> mes("Sister Aelle...")
    |> mes("Are you still trying")
    |> mes("to sell illegal warps")
    |> mes("again? Sister Aelle?")
    |> next()
    |> mes("[Aelle]")
    |> mes("Oh crap, it's the pastor!")
    |> mes("Shhh, if anybody asks you,")
    |> mes("I wasn't doing anything!")
    |> emotion(:huk)
    |> next()
    |> mes("[Aelle]")
    |> mes("Thanks, hon...")
    |> mes("I know you can")
    |> mes("keep my contraband")
    |> mes("our little secret. ^333333*Wink*^000000")
    |> emotion(:best)
    |> close()
  end

  defp meet_sister(ctx) do
    ctx
    |> warp_pitch()
    |> player_says()
    |> mes("Actually, um, I'm here")
    |> mes("to look for somebody.")
    |> mes("You wouldn't happen")
    |> mes("to know Canelle's")
    |> mes("sister, would you?")
    |> next()
    |> mes("[Aelle]")
    |> mes("Ah, so my stuck up")
    |> mes("sister sent you, huh?")
    |> mes("I should have known,")
    |> mes("judging from your clothes.")
    |> mes("So you want to become a")
    |> mes("more alluring performer, eh?")
    |> next()
    |> mes("[Aelle]")
    |> mes("Awww...")
    |> mes("That's disappointing.")
    |> mes("So... You didn't come")
    |> mes("here to buy these warps?")
    |> mes("You sure you don't want any?")
    |> set_char_var(:DANCER_SK, 4)
    |> close()
  end

  defp ask_for_food(ctx) do
    ctx
    |> mes("[Aelle]")
    |> mes("Okay, okay...")
    |> mes("So you came for me to")
    |> mes("teach you some enticement")
    |> mes("technique or something, right?")
    |> mes("Huh. Well, this lecture I give?")
    |> mes("It's long and complicated.")
    |> next()
    |> mes("[Aelle]")
    |> mes("Talking and explaining")
    |> mes("all of the intricate details")
    |> mes("for so long will definitely")
    |> mes("parch my throat. So first, you")
    |> mes("gotta bring me a refreshing")
    |> mes("drink before we can begin...")
    |> next()
    |> player_says()
    |> mes("Oh... Okay.")
    |> mes("Alright, I guess")
    |> mes("I can spare a potion")
    |> mes("or two, or maybe bring")
    |> mes("back a bottle of juic--")
    |> next()
    |> mes("[Aelle]")
    |> mes("Whoa, whoa, none of")
    |> mes("that junk! I want to")
    |> mes("have a real drink.")
    |> mes("You know, something")
    |> mes("more... ^FF0000Alcohol^000000ic.")
    |> next()
    |> mes("[Aelle]")
    |> mes("Oh, and I need some")
    |> mes("snacks to sustain all of")
    |> mes("my teaching energy! Yeah,")
    |> mes("some yummy fruit on a plate")
    |> mes("and some cookies too!")
    |> next()
    |> food_order()
    |> next()
    |> mes("[Aelle]")
    |> mes("One last thing...!")
    |> mes("Don't let anyone here")
    |> mes("in the church know what")
    |> mes("we're doing. I don't wanna")
    |> mes("get in too much trouble!")
    |> set_char_var(:DANCER_SK, 5)
    |> close()
  end

  defp check_food(ctx) do
    if count_item(ctx, @alcohol) > 0 and count_item(ctx, @apple) > 0 and
         count_item(ctx, @banana) > 2 and count_item(ctx, @well_baked_cookie) > 4 and
         count_item(ctx, @china) > 0 do
      drunken_lesson(ctx)
    else
      ctx
      |> mes("[Aelle]")
      |> mes("How can you expect")
      |> mes("me to teach you anything")
      |> mes("if I faint in the middle of")
      |> mes("the lesson? That's right,")
      |> mes("I'll need some nourishing,")
      |> mes("yet delicious, snacks to eat~")
      |> next()
      |> food_order()
      |> close()
    end
  end

  defp drunken_lesson(ctx) do
    ctx
    |> mes("[Aelle]")
    |> mes("Great, you've brought")
    |> mes("the food! It's a good thing")
    |> mes("I'm famished because")
    |> mes("I'm going to finish it all!")
    |> next()
    |> mes("^3355FFAelle devoured the")
    |> mes("food like a ravenous,")
    |> mes("hungry beast that had")
    |> mes("been deprived for too long.^000000")
    |> next()
    |> mes("[Aelle]")
    |> mes("That was sooo good!")
    |> mes("I haven't eaten so much")
    |> mes("in such a long time! Then")
    |> mes("again, you don't get many")
    |> mes("chances to pig out in church.")
    |> mes("Ah, that's right, the lesson!")
    |> next()
    |> mes("[Aelle]")
    |> mes("Now, the easiest, most")
    |> mes("subtle and most appealing")
    |> mes("gesture of all time is the")
    |> mes("^FF0000wink^000000. It's saved me in times")
    |> mes("of crisis, and mastering it")
    |> mes("will enhance your charms.")
    |> next()
    |> mes("[Aelle]")
    |> mes("To the untrained eye,")
    |> mes("the wink only looks like")
    |> mes("a simple movement, right?")
    |> mes("You close one eye, and then")
    |> mes("you reopen that eye. But if")
    |> mes("you do it right... If you...")
    |> next()
    |> mes("[Aelle]")
    |> mes("Oh, it's been so long")
    |> mes("since I've had so much")
    |> mes("to drink! Ugh, f-feeling")
    |> mes("kinda--anyway, j-just close")
    |> mes("and yer-- ^333333*burp*^000000 winking")
    |> mes("is so so so so eeeeeasy~")
    |> next()
    |> mes("[Drunken Aelle]")
    |> mes("Do it! Copy me as")
    |> mes("I do it! Wink, j-just")
    |> mes("like this, okay? Y' see?")
    |> mes("^333333*Wiiiiiiiiiiiiiink*^000000")
    |> emotion(:best)
    |> next()
    |> player_says()
    |> mes("Wh-whoa...")
    |> mes("That was...")
    |> mes("It's so beautiful!")
    |> mes("And all with just")
    |> mes("a simple wink!")
    |> next()
    |> mes("[Totally Drunk Aelle]")
    |> mes("Y-yea... The...")
    |> mes("The secret ish...")
    |> mes("*Urp* It'sh in the--")
    |> mes("Bwahahahaahah!")
    |> mes("It's all spinning!")
    |> emotion(:smile)
    |> next()
    |> mes("^3355FFIn her drunken stupor,")
    |> mes("Aelle pummels you with")
    |> mes("her fists and laughs")
    |> mes("maniacally to herself.^000000")
    |> percent_heal(hp: -10, sp: 0)
    |> specialeffect2(:hit2)
    |> emotion(:think)
    |> delitem(@alcohol, 1)
    |> delitem(@apple, 1)
    |> delitem(@banana, 3)
    |> delitem(@well_baked_cookie, 5)
    |> delitem(@china, 1)
    |> set_char_var(:DANCER_SK, 6)
    |> close()
  end

  defp fall_asleep(ctx) do
    ctx
    |> player_says()
    |> mes("You still haven't told")
    |> mes("me the secret to making")
    |> mes("a simple wink have so")
    |> mes("much provocative charm.")
    |> mes("I really need to--")
    |> next()
    |> mes("[Totally Hammered Aelle]")
    |> mes("ZzzZzz... Huh?")
    |> mes("Yesh, I know, I'm...")
    |> mes("I'm a geeenius, yeah...")
    |> mes("...ZzzzZzzzZzZzzzZZZzz...")
    |> next()
    |> player_says()
    |> mes("W-wake up!")
    |> mes("I went through")
    |> mes("all this trouble to")
    |> mes("learn this technique!")
    |> next()
    |> mes("[Annoyed Aelle]")
    |> mes("SHADDUP!")
    |> mes("I'M SHLEEEEEPY!")
    |> mes("G-go away. Talk to")
    |> mes("Canell, my sister...")
    |> mes("...ZzzzzZzZZZzzzZZ....")
    |> set_char_var(:DANCER_SK, 7)
    |> close()
    |> warp("prontera", 156, 272)
  end

  defp still_asleep(ctx) do
    ctx
    |> player_says()
    |> mes("Aelle, I really")
    |> mes("need you to teach")
    |> mes("me everything else")
    |> mes("I need to know about")
    |> mes("winking and--")
    |> next()
    |> mes("[Aelle]")
    |> mes("^333333*Hiccup*^000000 Zzz--wha?")
    |> mes("I need ta teach you")
    |> mes("to go'way. Talk to my")
    |> mes("sister, too tired now.")
    |> mes("Go lemme alone girl!")
    |> close()
    |> warp("prontera", 156, 272)
  end

  defp sober_up(ctx) do
    ctx
    |> mes("[Sober Aelle]")
    |> mes("Ohhh...")
    |> mes("H-headache...")
    |> emotion(:fret)
    |> next()
    |> mes("[Aelle]")
    |> mes("Oh, wow, look at you!")
    |> mes("I can tell that you've")
    |> mes("become much more")
    |> mes("beautiful. Yes, you're")
    |> mes("more elegant and refined")
    |> mes("than I can remember.")
    |> next()
    |> mes("[Aelle]")
    |> mes("Always believe in your")
    |> mes("beauty, wield your charm")
    |> mes("like a weapon... And anything")
    |> mes("you desire in this world can")
    |> mes("be yours! Bwahahahahaha!")
    |> close()
  end
end
