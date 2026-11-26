defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.FlamingSpiritMan do
  @moduledoc """
  Engel, a smith training in the Mjolnir mines, restores the Sobbing Starlight and later works
  on The Sign for the Sign quest.

  ## Behavior

  - Before the quest reaches him, asks to borrow an Iron Ore or turns the player out of his forge.
  - Takes his daughter's letter and the Sobbing Starlight fragments, then asks for 5 Mini
    Furnaces, 2 Oridecon Hammers and an anvil.
  - The anvil quality sets the chance that the restoration succeeds; on failure he asks for the
    tools again with a Golden or Emperium Anvil and repairs the ore on the spot.
  - Takes The Sign and hands back the finished item once the clock has moved two 2-hour slots
    past the moment he started.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjo_dun02",
        x: 88,
        y: 295,
        dir: 4,
        sprite: 85,
        name: "Flaming Spirit Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @anvil_ids [986, 987, 988, 989]

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if checkweight(ctx, [{908, 200}]) == 0 do
      ctx
      |> mes("^3355FFWait a second! Right now,")
      |> mes(
        "you have too many items in your inventory. Please come back after you've freed up more inventory space.^000000"
      )
      |> close()
    else
      ctx
      |> mes("[Engel]")
      |> talk(get_char_var(ctx, :sign_q, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk(ctx, quest) do
    cond do
      quest > 1 and quest < 54 -> iron_ore_request(ctx)
      quest < 56 -> ctx |> forge_closed() |> close2() |> emotion(:hng)
      quest == 56 -> letter_delivery(ctx)
      quest == 57 -> first_restoration(ctx)
      quest < 66 -> still_working(ctx)
      quest < 70 -> restoration_outcome(ctx, quest)
      quest == 70 -> second_restoration(ctx)
      quest < 139 -> ctx |> how_have_you_been() |> close()
      quest == 139 -> receive_the_sign(ctx)
      quest == 140 -> the_sign_progress(ctx)
      true -> farewell(ctx)
    end
  end

  defp iron_ore_request(ctx) do
    if count_item(ctx, 1002) > 0 do
      {ctx, choice} =
        ctx
        |> mes("Just as I suspected...")
        |> mes("I didn't bring enough of them.")
        |> mes("Hmm, this is serious. What")
        |> mes("am I going to do about this?")
        |> next()
        |> mes("[Engel]")
        |> mes("Oh great! I see that you're")
        |> mes(
          "carrying some Iron Ores with you. Would you be so kind as to lend me 1 Iron Ore? Please, I beg of you..."
        )
        |> next()
        |> select(["Sure, why not?", "Sorry, I can't."])

      case choice do
        1 ->
          ctx
          |> mes("[Engel]")
          |> mes("Thank you so much!")
          |> mes("If it weren't for your help,")
          |> mes(
            "I'd be in big trouble. I really appreciate you stepping in and volunteering your materials like this."
          )
          |> delitem(1002, 1)
          |> getexp(10, 0)
          |> close()

        2 ->
          ctx
          |> mes("[Engel]")
          |> mes("I suppose I understand.")
          |> mes(
            "However, you're lucky that I don't kick you out of my forge right here and right now~"
          )
          |> close2()
          |> emotion(:hng)

        _ ->
          ctx
      end
    else
      ctx
      |> forge_closed()
      |> emotion(:hng)
      |> close2()
      |> warp("mjo_dun02", 372, 346)
    end
  end

  defp forge_closed(ctx) do
    ctx
    |> mes("I hope you understand that")
    |> mes(
      "this forge isn't really open to the public. I'm doing some intensive training,so I'd appreciate it if you would just leave now."
    )
  end

  defp letter_delivery(ctx) do
    ctx =
      ctx
      |> mes("^333333*Sigh*^000000")
      |> mes("It's been a long")
      |> mes("time since I've seen")
      |> mes("my family. I really should let them know how I'm doing sooner or later. Hmmm....")
      |> next()
      |> mes("[Engel]")
      |> mes("...?")

    if count_item(ctx, 7276) > 0 do
      {ctx, choice} =
        ctx
        |> mes("Were you looking for me?")
        |> mes(
          "I'm sorry, but I'm busy at the moment. Please don't disturb me while I try to get my work done."
        )
        |> next()
        |> select(["I need your help.", "Here is a letter for you.", "I am leaving, leaving."])

      case choice do
        1 ->
          ctx
          |> mes("[Engel]")
          |> mes("Well, I'd like to help you,")
          |> mes("but now isn't a good for me.")
          |> mes(
            "plenty of other good smiths out there who can help you with the work that you want done. Farewell."
          )
          |> close()

        2 ->
          read_letter(ctx)

        3 ->
          ctx
          |> mes("[Engel]")
          |> mes("Alright, then.")
          |> mes("Take care.")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("Do you have any business")
      |> mes("me? I'm sorry, but right")
      |> mes("now I'm very busy. Please leave")
      |> mes("me alone to my research.")
      |> close()
    end
  end

  defp read_letter(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Engel]")
      |> mes("Oh, are you serious?")
      |> mes("Let me read it first.")
      |> next()
      |> mes("[Engel]")
      |> mes("Yes, yes.")
      |> mes("...Hahaha!")
      |> mes("It's so good to hear from")
      |> mes("my darling daughter.")
      |> next()
      |> mes("[Engel]")
      |> mes(
        "Thanks, I really appreciate that you've delivered this letter for me. Now, is there anything you'd like to ask of me? If it's not a big favor, I can probably help you."
      )
      |> next()
      |> select(["Please look at this."])

    case choice do
      1 -> request_tools(ctx)
      _ -> ctx
    end
  end

  defp request_tools(ctx) do
    ctx
    |> mes("[Engel]")
    |> mes("Oh?")
    |> mes("Isn't this...?")
    |> mes("I see, I see!")
    |> next()
    |> mes("[Engel]")
    |> mes(
      "Long ago, my old master told me that there are these strange ores that have fallen from the sky. The most beautiful and mysterious is the one shines just like a star."
    )
    |> next()
    |> mes("[Engel]")
    |> mes(
      "Most people may know it as Sobbing Starlight, but my master used to call it God's Tear Drop."
    )
    |> next()
    |> mes("[Engel]")
    |> mes(
      "However, this ore has been shattered into pieces. Judging from the smoothness of the edges, its inner power must have caused it to break apart. So you want me to put this back together, don't you?"
    )
    |> next()
    |> mes("[Engel]")
    |> mes("This will be a good challenge")
    |> mes("for me! However, I'll need some")
    |> mes(
      "special tools and materials to repair this kind of ore. Now, I want you to bring me the following things..."
    )
    |> next()
    |> mes("[Engel]")
    |> tool_list()
    |> mes("Now keep in mind that ordinary anvils won't be good enough for")
    |> mes("this kind of work.")
    |> next()
    |> mes("[Engel]")
    |> mes(
      "Now, an Emperium Anvil would be ideal for this job. I used to have one, but a while back I ended up giving it to someone. Anyway, I'll wait here for you while you gather everything you need."
    )
    |> next()
    |> mes("[Engel]")
    |> mes(
      "Right. Let me guide you to a shortcut to the exit of these mines, just in case you don't know your way out of here. Good luck~"
    )
    |> delitem(7276, 1)
    |> delitem(7177, 7)
    |> set_char_var(:sign_q, 57)
    |> close2()
    |> warp("mjo_dun02", 371, 344)
  end

  defp first_restoration(ctx) do
    ctx =
      ctx
      |> mes(
        "As I've told you before, I'm more likely to succeed in my work if I'm able to use a higher quality anvil. Let's me see what you've brought..."
      )
      |> next()

    if has_tools?(ctx) do
      anvil = anvil_tier(ctx)

      ctx
      |> mes("[Engel]")
      |> anvil_remark(anvil)
      |> next()
      |> mes("[Engel]")
      |> mes(
        "While I'm working on this, would you deliver a letter to my family for me? I'm sorry, but please consider that I'm waiving the fee for restoring this Sobbing Starlight."
      )
      |> next()
      |> mes("[Engel]")
      |> mes("Well then...")
      |> mes("I wish you safety")
      |> mes("in your travels.")
      |> delitem(612, 5)
      |> delitem(615, 2)
      |> delitem(Enum.at(@anvil_ids, anvil), 1)
      |> set_char_var(:sign_q, 58 + anvil)
      |> give_item(7278, 1)
      |> close()
    else
      ctx
      |> mes("[Engel]")
      |> missing_tools()
    end
  end

  defp anvil_remark(ctx, 0) do
    ctx
    |> mes("A...")
    |> mes("Regular Anvil?")
    |> mes("Alright, I guess I'll try it.")
    |> mes("But I can't guarantee success.")
  end

  defp anvil_remark(ctx, 1) do
    ctx
    |> mes("Ah...")
    |> mes("An Oridecon Avil.")
    |> mes("This isn't too bad,")
    |> mes("but there's a good risk")
    |> mes("that this might not work.")
  end

  defp anvil_remark(ctx, 2) do
    ctx
    |> mes("Ah...")
    |> mes("A Golden Anvil.")
    |> mes(
      "This just might be able to do the job. This might take a while, so I have something to ask of you."
    )
  end

  defp anvil_remark(ctx, 3) do
    ctx
    |> mes("Oh wow, an Emperium Anvil!")
    |> mes(
      "And this looks like one I might have actually made. Great, I should be able to do this so long as I don't make any critical mistakes~"
    )
  end

  defp still_working(ctx) do
    ctx
    |> mes("Are you back already?")
    |> mes(
      "Sorry, but I haven't quite finished yet. I won't be done for a while, so why don't you deliver that letter to my family?"
    )
    |> close()
  end

  defp restoration_outcome(ctx, quest) do
    if restored?(quest) do
      ctx
      |> mes("Are you back already?")
      |> mes(
        "While you were gone, I managed to restore this Sobbing Starlight. Why don't you go ahead and take a look?"
      )
      |> next()
      |> set_char_var(:sign_q, 71)
      |> give_item(7178, 1)
      |> specialeffect2(:yufitelhit)
      |> next()
      |> mes("[Engel]")
      |> mes(
        "This was one of the most difficult jobs I've ever done. But look! It was beautiful when broken in fragments but now it's absolutely dazzling! This was really worth my effort."
      )
      |> next()
      |> mes("[Engel]")
      |> mes(
        "In any case, I worked really hard to do a good job on this, so I hope you treasure this Sobbling Starlight, young adventurer."
      )
      |> close()
    else
      restoration_failed(ctx, quest)
    end
  end

  defp restored?(66), do: Enum.random(1..100) < 38
  defp restored?(67), do: Enum.random(1..100) < 67
  defp restored?(68), do: Enum.random(1..100) < 91
  defp restored?(69), do: true

  defp restoration_failed(ctx, quest) when quest in [66, 67] do
    ctx
    |> mes("You've returned?")
    |> mes(
      "Well, I don't know how to put this, but once you hear it, don't take it the wrong way..."
    )
    |> emotion(:profusely_sweat)
    |> next()
    |> mes("[Engel]")
    |> mes("^333333*Ahem*^000000")
    |> mes(
      "Just as I've warned you, this attempt to restore the Sobbling Starlight failed because the anvil you gave me wasn't up to the job. I'm sorry about that."
    )
    |> next()
    |> mes("[Engel]")
    |> mes("However, I only")
    |> mes("broke all of the tools")
    |> mes(
      "and the ore pieces are still intact. Now, if you bring me the tools one more time, I can try this again."
    )
    |> next()
    |> mes("[Engel]")
    |> mes(
      "Since I'm a bit more familiar with this material, I won't take so much time. Once again, let me tell you which things you need to bring..."
    )
    |> next()
    |> mes("[Engel]")
    |> tool_list()
    |> mes("And this time, bring")
    |> mes("me a better anvil, huh?")
    |> next()
    |> mes("[Engel]")
    |> mes(
      "Although it'd be perfect if I had an Emperium Anvil, I'm pretty sure it'll be alright if we used a Golden Anvil."
    )
    |> set_char_var(:sign_q, 70)
    |> close()
  end

  defp restoration_failed(ctx, 68) do
    ctx
    |> mes("Oh good, you're back.")
    |> mes("I've got some bad news,")
    |> mes("so please don't overreact~")
    |> mes("Um, are you ready?")
    |> emotion(:profusely_sweat)
    |> next()
    |> mes("[Engel]")
    |> mes("While I was trying to restore the ")
    |> mes("Sobbling Starlight, I was attacked ")
    |> mes("by monsters all of a sudden. If only")
    |> mes("I paid more attention to my")
    |> mes("surroundings...")
    |> next()
    |> mes("[Engel]")
    |> mes(
      "Please understand that I get very deeply engrossed in my smithing work. If you don't mind, I'll try this again you'll bring all the tools just like the last time."
    )
    |> next()
    |> mes("[Engel]")
    |> mes("^FF00005 Mini Furnace^000000 and")
    |> mes("^FF00002 Oridecon Hammer^000000.")
    |> mes(
      "Don't forget the ^FF0000Golden Anvil^000000! But if you can get your hands on one, an ^FF0000Emperium Anvil^000000 would be better."
    )
    |> set_char_var(:sign_q, 70)
    |> close()
  end

  defp second_restoration(ctx) do
    if has_tools?(ctx) do
      case anvil_tier(ctx) do
        anvil when anvil in [0, 1] ->
          ctx
          |> mes(
            "Didn't I tell you to bring me a Golden Anvil or an Emperium Anvil? Anything less isn't good enough to do any restoration work on this Sobbing Starlight."
          )
          |> next()
          |> mes("[Engel]")
          |> mes("Next time you come")
          |> mes(
            "here, bring a Golden or Emperium Anvil and make sure to leave all of your other anvils in Kafra Storage or something, okay?"
          )
          |> close()

        2 ->
          ctx
          |> mes("Good, good.")
          |> mes(
            "I see that you've brought a Golden Anvil. Now I can get started right away! Still, I'm a little about those monsters showing up again, so would you keep a lookout?"
          )
          |> repair_ore(988)

        3 ->
          ctx
          |> mes(
            "Excellent! You've brought an Emperium Anvil! Now, keep a lookout for monsters while I repair these ore fragments. We can't have those beasts ruin my work again, right? Thank you."
          )
          |> repair_ore(989)
      end
    else
      missing_tools(ctx)
    end
  end

  defp repair_ore(ctx, anvil_id) do
    ctx
    |> next()
    |> mes("^3355FF*Clink*")
    |> mes("*Clink Clink Clink*")
    |> mes("*Clink Clink Clink*")
    |> mes("*Cliiiiiiiiiiiiink*^000000")
    |> next()
    |> specialeffect(:repairweapon)
    |> next()
    |> mes("^3355FF*Clink*")
    |> mes("*Clink-Clink*")
    |> mes("*Clink-Clink-Clink*")
    |> mes("*Claaaaaaaaaaack*^000000")
    |> next()
    |> specialeffect(:repairweapon)
    |> next()
    |> mes("[Engel]")
    |> mes("It's almost done.")
    |> mes("Just be a bit more patient...")
    |> next()
    |> specialeffect(:repairweapon)
    |> next()
    |> mes("^3355FF*Tink Tink*^000000")
    |> mes(" ")
    |> mes("...*Tonk*^000000")
    |> next()
    |> specialeffect(:repairweapon)
    |> next()
    |> specialeffect(:flasher)
    |> next()
    |> mes("[Engel]")
    |> mes("Finally... Completed.")
    |> mes(
      "^333333*Phew!*^000000 That was one of the toughest jobs I've ever done, but this was well worth all of our efforts. Just look at the dazzling beauty of this Sobbing Starlight!"
    )
    |> next()
    |> mes("[Engel]")
    |> mes(
      "We've both gone through a lot of trouble to make this, so I hope you treasure your Sobbing Starlight. Good luck on your adventures..."
    )
    |> delitem(anvil_id, 1)
    |> set_char_var(:sign_q, 71)
    |> give_item(7178, 1)
    |> specialeffect2(:yufitelhit)
    |> close()
  end

  defp has_tools?(ctx) do
    count_item(ctx, 612) > 4 and count_item(ctx, 615) > 1 and anvil_tier(ctx) != nil
  end

  defp anvil_tier(ctx), do: Enum.find_index(@anvil_ids, &(count_item(ctx, &1) > 0))

  defp missing_tools(ctx) do
    if Enum.random(1..6) == 3 do
      ctx
      |> mes(
        "Oh, you don't have everything ready yet? Take your time, so long as you didn't forget what you needed to bring. You do remember, right?"
      )
      |> next()
      |> mes("[Engel]")
      |> tool_list()
      |> mes("That's all you need!")
      |> next()
      |> mes("[Engel]")
      |> mes(
        "Remember that I have a greater chance of repairing the Sobbing Starlight if I have access to a higher quality Anvil. Otherwise..."
      )
      |> close()
    else
      ctx
      |> mes(
        "Still don't have everything ready? That's fine, just take your time. So long as you haven't forgotten all the things that you need. I mean, how can you forget when you have such an important ore on you?"
      )
      |> close()
    end
  end

  defp tool_list(ctx) do
    ctx
    |> mes("^FF00005 Mini Furnace^000000,")
    |> mes("^FF00002 Oridecon Hammer^000000,")
    |> mes("and ^ff00001 good quality Anvil^000000.")
  end

  defp how_have_you_been(ctx) do
    mes(
      ctx,
      "How have you been doing lately? Feel free to ask me if you ever think that you need my expertise, alright?"
    )
  end

  defp receive_the_sign(ctx) do
    {ctx, _} =
      ctx
      |> mes("How have you been")
      |> mes("doing lately? You seem")
      |> mes("quite well. So is there anything")
      |> mes("I can help you with today?")
      |> next()
      |> select(["I need your help again."])

    {ctx, _} =
      ctx
      |> mes("[Engel]")
      |> mes("Haha, so what have")
      |> mes("you brought me this time?")
      |> mes("It must be fairly important if you've brought it all the way")
      |> mes("down here.")
      |> next()
      |> select(["Please look at this."])

    ctx
    |> mes("[Engel]")
    |> mes("Isn't this...?!")
    |> mes("Amazing, just by looking at it,")
    |> mes("I can feel its power! You really")
    |> mes("are something! How do you come across all of this amazing stuff?")
    |> next()
    |> mes("[Engel]")
    |> mes("You know, I consider myself")
    |> mes(
      "lucky to even see this kind of stuff. Most smiths might be able to see this kind of thing only once in their entire lives. And to be able to work on it..."
    )
    |> next()
    |> mes("[Engel]")
    |> mes("Hmmm...")
    |> mes("It's going to take quite")
    |> mes("a while to work on this. Unfortunately, I can't even")
    |> mes("give you a time estimate...")
    |> mes("But I'll do my best for you.")
    |> delitem(7314, 1)
    |> set_char_var(:sign_q, 140)
    |> then(&set_char_var(&1, :sign_sq, hour_slot(gettime(&1, 3))))
    |> close()
  end

  defp the_sign_progress(ctx) do
    if get_char_var(ctx, :sign_sq, 0) == slot_two_before(hour_slot(gettime(ctx, 3))) do
      ctx
      |> mes("It's so...")
      |> mes("Beautiful! I don't know")
      |> mes("if I'll ever see anything")
      |> mes("like this again in my life...")
      |> next()
      |> mes("[Engel]")
      |> mes("Oh, you're back just in time.")
      |> mes(
        "Although it was one of my most difficult jobs, I believe you'll be pleased with my work. Only a few smiths are privileged enough to work with this, even just once."
      )
      |> next()
      |> mes("[Engel]")
      |> mes("This is now yours to keep.")
      |> mes("Thank you for giving me the")
      |> mes("honor of working on a worthy")
      |> mes("smithing challenge.")
      |> set_char_var(:sign_q, 141)
      |> give_item(2644, 1)
      |> close()
    else
      ctx
      |> mes(
        "I haven't completed it yet, but please understand that I've got to be really careful when working with something so valuable. But don't worry, its inner power will be revealed when I'm finished."
      )
      |> close()
    end
  end

  defp hour_slot(hour), do: div(hour, 2) + 1

  defp slot_two_before(slot), do: rem(slot + 9, 12) + 1

  defp farewell(ctx) do
    ctx
    |> mes("Sometimes, you can only")
    |> mes(
      "improve yourself by training in solitude. But don't ever forget about the ones who really care about you. It's those people who make everything worth it."
    )
    |> close2()
    |> emotion(:think)
  end
end
