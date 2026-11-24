defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Chief do
  @moduledoc """
  Shi Yan Wen, the chief of Kunlun, starts and closes the Broken Sword quest for his stolen family
  sword.

  ## Behavior

  - Welcomes visitors; players above base level 50 start the quest on their first talk.
  - Tells of the robbery and lets the player offer to search for the sword or decline.
  - Rewards the thief's trail with 3 White Potions, or gives 1 White Potion to a player who
    gave up on the search.
  - When the player brings the sword's pieces, gives an Old Blue Box and either sends the player
    to Zuo Hei to find a blacksmith, or, if the player refuses, will repair it himself.
  - Takes the repaired Haedonggum in exchange for Shoes [1].

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_in",
        x: 17,
        y: 93,
        dir: 5,
        sprite: 775,
        name: "Chief",
        scope: :shared,
        unique_name: "Chief#gon"
      }
    ]

  @white_potion 504
  @old_blue_box 603
  @haedonggum 1123
  @slotted_shoes 2404

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) > 50 do
      talks_by_stage(ctx, get_char_var(ctx, :b_sword, 0))
    else
      welcomes(ctx)
    end
  end

  defp talks_by_stage(ctx, 0) do
    ctx
    |> set_char_var(:b_sword, 1)
    |> welcomes()
  end

  defp talks_by_stage(ctx, 1) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> introduces_the_village()
  end

  defp talks_by_stage(ctx, 2), do: asks_about_the_village(ctx)

  defp talks_by_stage(ctx, stage) when stage in [3, 4, 5] do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Haven't found it yet?")
    |> mes("There's no rush, take it easy.")
    |> mes("You have to take care of")
    |> mes("youself first before")
    |> mes("doing favors for others.")
    |> close()
  end

  defp talks_by_stage(ctx, 6) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Oh, you found a clue?")
    |> mes("So far, it looks like")
    |> mes("you're doing good work.")
    |> mes("Take this old family medicine, it might be of use sometime soon.")
    |> set_char_var(:b_sword, 7)
    |> give_item(@white_potion, 3)
    |> close()
  end

  defp talks_by_stage(ctx, 7) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("It might be helpful for you to")
    |> mes("know that the thief sustained")
    |> mes("an injury, so he is probably not very far from here.")
    |> close()
  end

  defp talks_by_stage(ctx, 8) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("What...?")
    |> mes("My sword has been broken!?")
    |> mes("Unbelievable~!!")
    |> mes("How could this happen??")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("First it's stolen, and now")
    |> mes("it's in pieces... *Sob*")
    |> mes("Would you please search")
    |> mes("for the rest of my sword?")
    |> mes("It means so much to my family...")
    |> close()
  end

  defp talks_by_stage(ctx, 9) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("*Sob*...")
    |> mes("...my sword... in pieces...")
    |> mes("I beg of you, please find them")
    |> mes("for me. I will give you something in return.")
    |> close()
  end

  defp talks_by_stage(ctx, 10), do: receives_the_pieces(ctx)

  defp talks_by_stage(ctx, 11) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("The village is not in a good")
    |> mes("mood these days, but there are")
    |> mes("still lots of things to see in Kunlun.")
    |> close()
  end

  defp talks_by_stage(ctx, 12) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Hmm.. no traces? No clues?")
    |> mes("... Nothing? Well, that's")
    |> mes("alright. Thank you for")
    |> mes("trying to help.")
    |> mes("Hmm....")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("Here...take this.")
    |> mes("Have a good time in Kunlun~")
    |> set_char_var(:b_sword, 13)
    |> give_item(@white_potion, 1)
    |> close()
  end

  defp talks_by_stage(ctx, 13) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Is everything going well?")
    |> mes("The village has not been")
    |> mes("in a good mood, lately.")
    |> mes("Still, please try to")
    |> mes("enjoy yourself.")
    |> close()
  end

  defp talks_by_stage(ctx, stage) when stage in [14, 15, 16, 17] do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("I really appreciate what you are")
    |> mes("doing. It's a big relief that")
    |> mes("something is finally being done")
    |> mes("about these thefts.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("Perhaps now, peace will finally")
    |> mes("come to the village, just like in the old days...")
    |> close()
  end

  defp talks_by_stage(ctx, stage) when stage > 17 and stage < 32 do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("I appreciate what you are doing,")
    |> mes("and your help has been")
    |> mes("a relief to me. The Village")
    |> mes("seems less tense, much like")
    |> mes("it was in the old days.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("Although I hope you'll be")
    |> mes("be able to repair my")
    |> mes("sword soon, you've")
    |> mes("already done so much for")
    |> mes("me. I feel sorry for")
    |> mes("asking you to do more.")
    |> close()
  end

  defp talks_by_stage(ctx, 32) do
    if count_item(ctx, @haedonggum) < 1 do
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes("Hm.....")
      |> mes("Not finished yet, huh?")
      |> mes("Still, it's good to know")
      |> mes("it's being repaired...")
      |> mes("I'll be waiting, then.")
      |> close()
    else
      receives_the_repaired_sword(ctx)
    end
  end

  defp talks_by_stage(ctx, _stage) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Oh, it's you~")
    |> mes("Once again, I'd like to thank")
    |> mes("you for all of your help.")
    |> mes("Enjoy your stay in our village.")
    |> mes("Heh heh~")
    |> close()
  end

  defp welcomes(ctx) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Hmm...?")
    |> introduces_the_village()
  end

  defp introduces_the_village(ctx) do
    ctx
    |> mes("Oh, hello there~")
    |> mes("I am Shi Yan Wen, the chief of")
    |> mes("this village. Allow me to personally welcome you to Kunlun.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("Although our village hasn't")
    |> mes("associated with other towns very")
    |> mes("much, we have recently begun")
    |> mes("to allow visitors coming from Alberta.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("I feel that this town has been")
    |> mes("isolated for too long. Because")
    |> mes("of that, people in this town aren't too friendly with visitors yet.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("Moreover, we've been having a recent problem with thieves")
    |> mes("that have been enjoying themselves far too much in Kunlun...")
    |> mes("Well, you've come to visit here")
    |> mes("so I hope you enjoy your stay.")
    |> close()
  end

  defp asks_about_the_village(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes("Oh, it's you~")
      |> mes("How do you like it here so far?")
      |> mes("As you've probably noticed,")
      |> mes("the village isn't that peaceful, huh?")
      |> next()
      |> select(["It's alright.", "I heard that something was stolen..."])

    if choice == 1 do
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes("Well, I'm glad you don't mind.")
      |> mes("Just watch out for robbers,")
      |> mes("and try not to act suspicious")
      |> mes("in the village.")
      |> close()
    else
      tells_of_the_robbery(ctx)
    end
  end

  defp tells_of_the_robbery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes("Hmm...you've heard of it?")
      |> mes("It was just last night when the")
      |> mes("robbery occurred. The rumors")
      |> mes("are true. Sadly, there are lots of thieves out there in the village...")
      |> next()
      |> select(["......", "What was stolen?", "Was anyone hurt?"])

    case choice do
      1 ->
        ctx
        |> mes("[Shi Yan Wen]")
        |> mes("I can't believe it really")
        |> mes("happened... Well, if you see")
        |> mes("any suspicious characters around,")
        |> mes("or find what was stolen, please let me know.")
        |> set_char_var(:b_sword, 3)
        |> close()

      2 ->
        ctx
        |> mes("[Shi Yan Wen]")
        |> mes("Well...")
        |> mes("Erm...it was...")
        |> mes("...just an ordinary sword.")
        |> mes("But to us, it's been a family treasure for many generations.")
        |> next()
        |> needs_the_sword_found("...but I can't go find it just", "um..Thank you.")

      3 ->
        ctx
        |> mes("[Shi Yan Wen]")
        |> mes("Fortunately, no one was hurt.")
        |> mes("However, the thieves took a")
        |> mes("valuable family treasure")
        |> mes("which has been passed down from")
        |> mes("generation to generation.")
        |> next()
        |> needs_the_sword_found("...But I can't go find it just", "Um..Thank you.")

      _ ->
        ctx
    end
  end

  defp needs_the_sword_found(ctx, cannot_search_line, thanks_line) do
    {ctx, choice} =
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes("I must find this sword")
      |> mes("no matter what!")
      |> mes(cannot_search_line)
      |> mes("by myself. I'm just too busy.")
      |> next()
      |> mes("[Shi Yan Wen]")
      |> mes("You know how busy it is to be the")
      |> mes("chief of a village. This is very troubling...*Sigh*")
      |> next()
      |> select(["Hope you find it soon.", "Can I find it for you?"])

    if choice == 1 do
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes(thanks_line)
      |> mes("If you somehow come across it,")
      |> mes("please let me know.")
      |> set_char_var(:b_sword, 11)
      |> close()
    else
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes("Oh!~ Are you serious??")
      |> mes("...The people in the village are")
      |> mes("very fearful these days because")
      |> mes("of the thieves. It is so difficult")
      |> mes("to ask them for help...")
      |> next()
      |> mes("[Shi Yan Wen]")
      |> mes("If you would help me find the sword, I will surely repay you for your efforts.")
      |> set_char_var(:b_sword, 3)
      |> close()
    end
  end

  defp receives_the_pieces(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shi Yan Wen]")
      |> mes("Oh!~")
      |> mes("You've found the pieces for me~")
      |> mes("I knew you could do it.")
      |> mes("But the sword is still shattered.")
      |> mes("What shall I do...?")
      |> next()
      |> mes("[Shi Yan Wen]")
      |> mes("If it's okay with you,")
      |> mes("would you repair my sword for me?")
      |> mes("I'll repay you for your help.")
      |> next()
      |> select(["No way.", "Alright."])

    if choice == 1, do: keeps_the_broken_sword(ctx), else: sends_to_zuo_hei(ctx)
  end

  defp keeps_the_broken_sword(ctx) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Well, I see...you've been such a")
    |> mes("nice person. I truly appreciate")
    |> mes("your hard work. It would be")
    |> mes("wonderful if you could help")
    |> mes("me repair the sword, but I")
    |> mes("will not force you.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("I'll find some way to repair")
    |> mes("it. Without your help, I ")
    |> mes("would have never found it.")
    |> mes("Please accept this as a")
    |> mes("token of my gratitude...")
    |> set_char_var(:b_sword, 15)
    |> give_item(@old_blue_box, 1)
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("If you find any information")
    |> mes("or clues about that cursed")
    |> mes("thief, please let me know.")
    |> mes("I have my sword back but")
    |> mes("there's no way I can forgive")
    |> mes("this affront to my ancestors...")
    |> close()
  end

  defp sends_to_zuo_hei(ctx) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Such generosity...")
    |> mes("I'm truly indebted to you...")
    |> mes("I have no idea how this sword")
    |> mes("broke into pieces, though.")
    |> mes("You will probably need to find a")
    |> mes("famous blacksmith to repair it.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("As I already mentioned, this is")
    |> mes("an important family treasure...")
    |> mes("Oh! I just remembered--")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("There's a guy named ^555555Zuo Hei^000000")
    |> mes("in the village. He has been to")
    |> mes("many places around the world.")
    |> mes("He may know of such a weaponsmith. Please seek this man out.")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("Oh, one last thing. This is")
    |> mes("but a trinket, but please")
    |> mes("accept this gift from me.")
    |> set_char_var(:b_sword, 14)
    |> give_item(@old_blue_box, 1)
    |> close()
  end

  defp receives_the_repaired_sword(ctx) do
    ctx
    |> mes("[Shi Yan Wen]")
    |> mes("Oh, it's you~ Hello.")
    |> mes("............")
    |> mes("Is that my sword?")
    |> mes("Wow, you've done it!")
    |> mes("Good work!")
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("This is a small gift for you.")
    |> mes("Please take it as thanks for a job well done!")
    |> delitem(@haedonggum, 1)
    |> set_char_var(:b_sword, 33)
    |> give_item(@slotted_shoes, 1)
    |> next()
    |> mes("[Shi Yan Wen]")
    |> mes("Thank you for all of your efforts.")
    |> mes("With this sword repaired, I no")
    |> mes("longer feel that I am shaming")
    |> mes("my ancestors...")
    |> mes("Heh heh...")
    |> mes("Have a good time in Kunlun.")
    |> close()
  end
end
