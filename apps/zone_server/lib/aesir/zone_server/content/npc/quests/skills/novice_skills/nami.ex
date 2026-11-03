defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.NoviceSkills.Nami do
  @moduledoc """
  Nami, an aspiring nurse in Prontera, teaches the First Aid quest skill to Novices.

  ## Behavior

  - Talks only with Novices and Baby Novices above Job Level 3 or Base Level 11 who have not
    finished the quest.
  - Explains First Aid and sends the player for 3 Red Herbs, 3 Clovers, and a Sterilized
    Bandage from the castle nurse.
  - After the nurse visit, teaches First Aid in exchange for the herbs and clovers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - IVBela
    - L0ne_W0lf
    - Masao
    - Zopokx

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "prt_in", x: 234, y: 133, dir: 4, sprite: 66, name: "Nami", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @first_aid 142
  @red_herb 507
  @clover 705

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if eligible?(ctx), do: offer_care(ctx), else: lack_experience(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp eligible?(ctx) do
    (Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) or
       Rathena.job_id(class(ctx)) == Rathena.job_id(:baby)) and
      (job_level(ctx) > 3 or base_level(ctx) > 11) and get_char_var(ctx, :skill_nov, 0) < 3
  end

  defp offer_care(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Nami]")
      |> mes("Hello!")
      |> mes("I want to be a nurse so bad!")
      |> mes("I always go and try to learn more.")
      |> mes("Actually, I'm really good.")
      |> mes("Do you want me to try on you? ? ? . .")
      |> next()
      |> select(["Continue conversation", "Slowly slink away. . . ."])

    case choice do
      1 -> quest_step(ctx, get_char_var(ctx, :skill_nov, 0))
      2 -> grab_patient(ctx)
      _ -> lack_experience(ctx)
    end
  end

  defp quest_step(ctx, 0), do: introduce_skill(ctx)
  defp quest_step(ctx, 1), do: remind_items(ctx)
  defp quest_step(ctx, 2), do: check_items(ctx)

  defp quest_step(ctx, _step) do
    ctx
    |> mes("[Nami]")
    |> mes(". . . . . Z z z")
    |> mes("I am so sorry!!!...I know I did it wrong...!!")
    |> mes("Wahhhh ..")
    |> mes("!! *sigh* !!")
    |> mes("- *rolls her eyes* -")
    |> close()
  end

  defp introduce_skill(ctx) do
    ctx
    |> mes("[Nami]")
    |> mes("Thank you for giving me this chance!")
    |> mes("I will do the best I can.")
    |> mes("When I am nursing people, I never")
    |> mes("give half effort. -")
    |> next()
    |> mes("[Nami]")
    |> mes("Let me explain to you about")
    |> mes("this skill I am using, ^3355FF' First Aid '^000000 ")
    |> mes("It doesn't take any special")
    |> mes("equipment or items . .")
    |> mes("Using only old cloth, left over potions,")
    |> mes("and some other unsubstantial materials")
    |> next()
    |> mes("[Nami]")
    |> mes("you can perform first aid. -")
    |> mes("It is a simple skill that you can use")
    |> mes("to regain a small amount of HP.")
    |> mes("I wouldn't mind teaching you. . .")
    |> mes("If you want to learn this skill,")
    |> mes("it does not take much to learn. . .")
    |> next()
    |> item_list("Red Herb")
    |> next()
    |> where_to_find()
    |> mes("[Nami]")
    |> mes("The only item you must take")
    |> mes("a special trip for is the bandage.")
    |> mes("On the eastern side second floor ")
    |> mes("of the prontera castle you can find")
    |> mes("a nurse who will supply you with this")
    |> mes("item readily. You should see her for this item")
    |> next()
    |> mes("[Nami]")
    |> mes("If you go and find these items, ")
    |> mes("I will be happy to teach you this skill.")
    |> mes("Well, I will be awaiting your return.")
    |> set_char_var(:skill_nov, 1)
    |> close()
  end

  defp remind_items(ctx) do
    ctx
    |> item_list("Red Herb")
    |> next()
    |> where_to_find()
    |> mes("[Nami]")
    |> mes("The only item you must take")
    |> mes("a special trip for is the bandage.")
    |> mes("Two maps east of here you can find")
    |> mes("a nurse who will supply you with this")
    |> mes("item readily. You should see her for")
    |> mes("this item. . . ")
    |> close()
  end

  defp check_items(ctx) do
    if count_item(ctx, @red_herb) > 2 and count_item(ctx, @clover) > 2 do
      teach(ctx)
    else
      ctx |> item_list("Red_Herb") |> close()
    end
  end

  defp teach(ctx) do
    ctx
    |> delitem(@red_herb, 3)
    |> delitem(@clover, 3)
    |> mes("[Nami]")
    |> mes("Hello, welcome back!")
    |> mes("You have done well at finding")
    |> mes("the necessary items.")
    |> mes("I know that the Nurse is a little")
    |> mes("strange, I am sure it was a little perplexing. . .")
    |> mes("hee hee hee . . . . .")
    |> next()
    |> mes("[Nami]")
    |> mes("Well, let us begin our training.")
    |> mes("When using the first aid skill")
    |> mes("you will use about 3 SP and convert")
    |> mes("this energy into about 5 HP.")
    |> mes("This is done with your first aid skill")
    |> mes("and supplies.")
    |> next()
    |> mes("[Nami]")
    |> mes("You should take this and place it here. . .")
    |> mes("Then you can stop the bleeding. . .")
    |> mes("After that you should apply this. . .")
    |> mes("There!!! Isn't it easy? ! ? !")
    |> next()
    |> mes("[Nami]")
    |> mes(". . Basically.")
    |> mes("You can take a little of left")
    |> mes("herbs and common items")
    |> mes("and combine them together and. . .")
    |> mes("Presto !!")
    |> next()
    |> skill(@first_aid, 1, :permanent)
    |> set_char_var(:skill_nov, 3)
    |> mes("[Nami]")
    |> mes("Yes yes, that's right!")
    |> mes("Now that you have this")
    |> mes("skill, I hope that it helps you")
    |> mes("in the future.")
    |> mes("Thank you and have a great day !~~~")
    |> close()
  end

  defp item_list(ctx, red_herb) do
    ctx
    |> mes("[Nami]")
    |> mes("First aid does require")
    |> mes("some small preparations. . .")
    |> mes("Some simple items you should have on hand are")
    |> mes("^3355FF' 3 #{red_herb} '^000000 ")
    |> mes("^3355FF' 3 Clover '^000000 ")
    |> mes("^3355FF' 1 Sterilized Bandages '^000000 ")
  end

  defp where_to_find(ctx) do
    ctx
    |> mes("[Nami]")
    |> mes("You can find these items being")
    |> mes("carried by monsters close by or")
    |> mes("even buy them from a merchant.")
    |> mes("It shouldn't be difficult to prepare")
    |> mes("these items for your first aid skill.")
    |> next()
  end

  defp grab_patient(ctx) do
    ctx
    |> mes("[Nami]")
    |> mes("Hey! .. Where are you going? !")
    |> mes("Come over here and have a shot !")
    |> mes("Prick and its over !!")
    |> mes("Grab that patient! ! !")
    |> close()
  end

  defp lack_experience(ctx) do
    ctx
    |> mes("[Nami]")
    |> mes("I am working hard to receive")
    |> mes("my nursing license . . .")
    |> mes("I don't think that I lack anything")
    |> mes("to become a nurse . .")
    |> mes("It must be because of my lack of my experience ?")
    |> next()
    |> mes("[Nami]")
    |> mes("If only you had at least")
    |> mes("a first job . .")
    |> mes("or maybe be over ^3355FF novice job level 4^000000")
    |> mes("I could have talked to")
    |> mes("you a little longer. . . . . . .")
    |> close()
  end
end
