defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.ItemTutor do
  @moduledoc """
  Teaches novice item, equipment, and hotkey use and supplies training items.

  ## Behavior

  - Explains consumables, equipment, and hotkeys.
  - Provides training items and lesson experience while tracking course progress.
  - Directs trainees to unfinished courses or field combat training.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-2",
        x: 115,
        y: 111,
        dir: 3,
        sprite: 726,
        name: "Item Tutor",
        unique_name: "Item Tutor#nv"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      essential_courses_complete?(ctx) -> completed_courses_menu(ctx)
      get_char_var(ctx, :nov_get_item04, 0) < 10 -> offer_item_lesson(ctx)
      get_char_var(ctx, :nov_get_item02, 0) < 10 -> direct_to_interfaces_tutor(ctx)
      get_char_var(ctx, :nov_get_item03, 0) < 10 -> direct_to_skill_tutor(ctx)
      true -> ctx
    end
  end

  defp essential_courses_complete?(ctx) do
    get_char_var(ctx, :nov_get_item02, 0) > 9 and
      get_char_var(ctx, :nov_get_item03, 0) > 9 and
      get_char_var(ctx, :nov_get_item04, 0) > 9
  end

  defp completed_courses_menu(ctx) do
    case ctx
         |> mes("[Alice]")
         |> mes("Huh...?")
         |> mes(
           "Do you need help looking for someone? You seem to have completed all of the essential courses. Where do you need to go?"
         )
         |> next()
         |> select(["I'm not sure~!", "Send me to a town.", "Cancel"]) do
      {ctx, 1} -> completed_field_combat_offer(ctx)
      {ctx, 2} -> completed_town_advice(ctx)
      {ctx, 3} -> ctx |> mes("[Alice]") |> mes("Hmpf...!") |> close()
      {ctx, _choice} -> ctx
    end
  end

  defp completed_field_combat_offer(ctx) do
    case ctx
         |> mes("[Alice]")
         |> mes("Hmm...")
         |> mes("You've learned everything else,")
         |> mes(
           "so I guess the only thing left is Field Combat Training. Did you want to attend that class now?"
         )
         |> next()
         |> select(["Yes.", "Oh, w-wait."]) do
      {ctx, 1} ->
        ctx
        |> mes("[Alice]")
        |> mes(
          "Make sure you keep the items I've given you handy, and that you equip all of your armor, alright? Now, take care."
        )
        |> close()
        |> warp("new_1-2", 28, 178)

      {ctx, 2} ->
        ctx
        |> mes("[Alice]")
        |> mes("Okay, no problem.")
        |> mes("Come to me when you")
        |> mes("need any help.")
        |> close()

      {ctx, _choice} ->
        ctx
    end
  end

  defp offer_item_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Alice]")
      |> mes("^666666*Yawn~*^000000")
      |> mes("This is so boring.")
      |> mes("Oh! Hello, you're new here.")
      |> renew_expired_registration()

    case ctx
         |> mes("So, have you come to attend")
         |> mes("my Item Information class?")
         |> next()
         |> select(["Yes!", "No, thanks.", "How do I get to a town?"]) do
      {ctx, 1} -> item_lesson(ctx)
      {ctx, 2} -> confirm_field_combat(ctx, "No, no! Send me to the actual fight class!")
      {ctx, 3} -> town_advice(ctx)
      {ctx, _choice} -> ctx
    end
  end

  defp renew_expired_registration(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :NEW_MES_FLAG0, 0)) do
      ctx
      |> mes(
        "Ooh, your proof of registration was expired. But that's okay, I'll just give you a new one! There you go."
      )
      |> set_char_var(:NEW_MES_FLAG0, 0)
      |> set_char_var(:NEW_MES_FLAG1, 0)
      |> set_char_var(:NEW_MES_FLAG2, 0)
      |> set_char_var(:NEW_MES_FLAG3, 0)
      |> set_char_var(:NEW_MES_FLAG4, 0)
      |> set_char_var(:NEW_MES_FLAG5, 0)
      |> set_char_var(:NEW_LVUP0, 0)
      |> set_char_var(:NEW_LVUP1, 0)
      |> set_char_var(:NEW_JOBLVUP, 0)
    else
      ctx
    end
  end

  defp item_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Alice]")
      |> mes("Don't worry, it'll be short.")
      |> mes("Open your Inventory Window")
      |> mes(
        "through either the '^3355FFitems^000000' button in the Basic Info window, or by pressing the '^3355FFAlt^000000' and '^3355FFE^000000' keys at the same time."
      )
      |> next()
      |> mes("[Alice]")
      |> mes(
        "In the Inventory Window, you'll see 3 tabs labeled ^3355FFitem^000000, ^3355FFequip^000000 and ^3355FFetc^000000. Items that can be consumed are under the ^4A708Bitem^000000 tab."
      )
      |> next()
      |> mes("[Alice]")
      |> mes(
        "Now, would you click the ^4A708Bitem^000000 tab in the Inventory Window? I just gave you a Novice Potion. You can drink it by double-clicking it. Go ahead, try it!"
      )
      |> set_char_var(:nov_get_item04, 10)
      |> give_item(569, 1)
      |> percent_heal(hp: -50, sp: 0)
      |> next()
      |> mes("[Alice]")
      |> respond_to_potion_use()
      |> next()
      |> mes("[Alice]")
      |> mes("Let me explain about")
      |> mes("items in the ^4A708Bequip^000000 tab")
      |> mes("of the Inventory Window.")
      |> next()
      |> mes("[Alice]")
      |> mes(
        "When you click on the ^4A708Bequip^000000 tab, you can view every item in your inventory that you can equip. Let me give you some equipment so that you can try them on."
      )
      |> next()
      |> mes("[Alice]")
      |> mes("Got them? Good.")
      |> mes("Now, double-click")
      |> mes("on the Novice Slippers")
      |> mes("I just gave you to")
      |> mes("put them on.")
      |> set_char_var(:nov_get_item04, 12)
      |> give_item(2510, 1)
      |> give_item(2414, 1)
      |> give_item(5055, 1)
      |> next()
      |> mes("[Alice]")
      |> respond_to_equipment_use()
      |> disable_items()
      |> next()
      |> mes("[Alice]")
      |> mes("Would you")
      |> mes("press the '^3355FFF12^000000' key?")
      |> mes("This will summon your")
      |> mes("Hotkey bar on your screen.")
      |> next()
      |> mes("[Alice]")
      |> mes(
        "You can assign hotkeys to your items, skills and equipment using the Hotkey bar. Just drag skill icons from the Skill Window or items from the Inventory Window into the Hotkey bar."
      )
      |> next()
      |> mes("[Alice]")
      |> mes("The Hotkeys are '^3355FFF1^000000' to '^3355FFF9^000000.'")
      |> mes(
        "If you have attended the Skill Class, you must have been given the First Aid skill. Drag and drop the First Aid skill icon into the Hotkey bar."
      )
      |> next()
      |> mes("[Alice]")
      |> mes("For your information, only")
      |> mes(
        "active skills can be assigned to a Hotkey and dragged to the Hotkey bar. Active Skills have colored, square shaped icons that can be double-clicked and used."
      )
      |> next()
      |> mes("[Alice]")
      |> mes(
        "Passive Skills, such as the aptly named 'Basic Skill,' cannot be dragged into the Hotkey bar because Passive Skills are always in effect and don't need to be activated."
      )
      |> set_char_var(:nov_get_item04, 14)
      |> grant_job_experience_if_eligible()
      |> next()
      |> mes("[Alice]")
      |> mes("Well, that's it!")
      |> mes("Let me supply you with some items")
      |> mes("that will help you during the Field Combat Training.")
      |> next()
      |> mes("[Alice]")
      |> mes(
        "However, ^ff0000do not use the Fly Wing or Butterfly Wing^000000 in these Training Grounds or you could be stuck here forever. Those items are for when you graduate, okay?"
      )
      |> set_char_var(:nov_get_item04, 15)
      |> give_item(601, 10)
      |> give_item(602, 2)
      |> give_item(569, 50)
      |> next()
      |> mes("[Alice]")
      |> mes("And lastly...")
      |> grant_final_job_experience()

    lesson_completion_menu(ctx)
  end

  defp respond_to_potion_use(ctx) do
    if count_item(ctx, 569) < 1 do
      if base_level(ctx) < 8 do
        ctx
        |> mes("Nice~!")
        |> mes("And here's")
        |> mes("a little reward")
        |> mes("just for listening.")
        |> set_char_var(:nov_get_item04, 11)
        |> grant_base_experience()
      else
        mes(
          ctx,
          "Good job! I'd reward you with some more experience if your level weren't already this high."
        )
      end
    else
      ctx
      |> mes("Um...")
      |> mes("Well, you can drink")
      |> mes("it later I guess.")
    end
  end

  defp respond_to_equipment_use(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2414)) do
      if base_level(ctx) < 8 do
        ctx
        |> mes("Hooray~!")
        |> mes("You did it!")
        |> mes("You deserve a reward!")
        |> set_char_var(:nov_get_item04, 13)
        |> grant_base_experience()
      else
        mes(
          ctx,
          "Good job! I'd reward you with some more experience if your level weren't already this high."
        )
      end
    else
      ctx
      |> mes("Er...")
      |> mes("You've got to")
      |> mes("double-click")
      |> mes("equipment to")
      |> mes("wear it. Just")
      |> mes("remember that, okay?")
    end
  end

  defp grant_job_experience_if_eligible(ctx) do
    if job_level(ctx) < 7, do: grant_job_experience(ctx), else: ctx
  end

  defp grant_final_job_experience(ctx) do
    if job_level(ctx) < 7 do
      ctx
      |> mes("I will give")
      |> mes("you some Job experience!")
      |> set_char_var(:nov_get_item04, 16)
      |> grant_job_experience()
    else
      mes(
        ctx,
        "I was gonna give you some job experience points, but I think you have enough job experience for now."
      )
    end
  end

  defp lesson_completion_menu(ctx) do
    case ctx
         |> next()
         |> select(["Now what?", "Send me to the actual fighting class!", "Cancel"]) do
      {ctx, 1} ->
        ctx
        |> mes("[Alice]")
        |> mes("Why don't you walk around")
        |> mes("and talk to other tutors if you haven't already?")
        |> next()
        |> mes("[Alice]")
        |> mes("Everyone in this training grounds is more than willing to help you.")
        |> mes("Maybe you can venture around")
        |> mes("this area if you're bored.")
        |> next()
        |> mes("[Alice]")
        |> mes(
          "The assistant tutors in the room to the right possess useful knowledge. There are also a few interesting places hidden within this area. Good luck!"
        )
        |> close()

      {ctx, 2} ->
        send_to_field_combat(ctx)

      {ctx, 3} ->
        ctx |> mes("[Alice]") |> mes("Hmpf!") |> close()

      {ctx, _choice} ->
        ctx
    end
  end

  defp direct_to_interfaces_tutor(ctx) do
    case ctx
         |> mes("[Alice]")
         |> mes("So how may")
         |> mes("I help you?")
         |> mes(
           "Hmm, it seems that you haven't attended the Basic Interfaces class yet. Would you like to attend that class first?"
         )
         |> next()
         |> select([
           "I am going to attend that class.",
           "Send me to Field Combat Training.",
           "Cancel"
         ]) do
      {ctx, 1} ->
        ctx
        |> mes("[Cecil]")
        |> mes("Excellent~")
        |> mes(
          "You'll learn some essential stuff and gain experience and items as you take that class. The tutor for Basic Interfaces is in the center of this room. Now, go for it~"
        )
        |> close()

      {ctx, 2} ->
        confirm_field_combat(ctx, "I want Field Combat Training~!")

      {ctx, 3} ->
        town_advice(ctx)

      {ctx, _choice} ->
        ctx
    end
  end

  defp direct_to_skill_tutor(ctx) do
    case ctx
         |> mes("[Alice]")
         |> mes("So how may")
         |> mes("I help you?")
         |> mes(
           "It looks like you still haven't attended the ^4d4dffthe Skill information class^000000 yet. Would you like to attend that class first?"
         )
         |> next()
         |> select([
           "I'll attend that class.",
           "Send me to Field Combat Training.",
           "Cancel"
         ]) do
      {ctx, 1} ->
        ctx
        |> mes("[Alice]")
        |> mes(
          "Now, that's a good idea. Please talk to Cecil, the tutor at the far left side of this room, okay?"
        )
        |> close()
        |> warp("new_1-2", 84, 107)

      {ctx, 2} ->
        confirm_field_combat(ctx, "I want Field Combat Training~!")

      {ctx, 3} ->
        town_advice(ctx)

      {ctx, _choice} ->
        ctx
    end
  end

  defp confirm_field_combat(ctx, confirm_choice) do
    case ctx
         |> mes("[Alice]")
         |> mes(
           "Are you sure you really want to go into Field Combat Training? Have you spoken to every tutor? You better do that beforehand."
         )
         |> next()
         |> select([confirm_choice, "Oh, wait!"]) do
      {ctx, 1} ->
        send_to_field_combat(ctx)

      {ctx, 2} ->
        ctx
        |> mes("[Alice]")
        |> mes(
          "Now, that's a good decision. You won't get any many chances to get free stuff and experience in the future. You better make the most of this opportunity while you can!"
        )
        |> close()

      {ctx, _choice} ->
        ctx
    end
  end

  defp send_to_field_combat(ctx) do
    ctx
    |> mes("[Alice]")
    |> mes(
      "What an enthusiastic Novice you are! Okay, I'll send you to the folks in charge of Field Combat Training. Make sure that you listen carefully to the trainers."
    )
    |> next()
    |> mes("[Alice]")
    |> mes("After all...")
    |> mes(
      "When you're fighting monsters, it's a matter of life and death! Alright then, take care~"
    )
    |> close()
    |> warp("new_1-2", 28, 178)
  end

  defp completed_town_advice(ctx) do
    ctx
    |> mes("[Alice]")
    |> mes("Ah, I see.")
    |> mes(
      "If you want to move to a town, the Kafra Lady to the right of me will teleport you. Take care now~"
    )
    |> close()
  end

  defp town_advice(ctx) do
    ctx
    |> mes("[Alice]")
    |> mes(
      "If you want to go to a town, ask the Kafra Employee to the right. Alright then, take care~"
    )
    |> close()
  end

  defp grant_base_experience(ctx) do
    case base_level(ctx) do
      1 -> getexp(ctx, 10, 0)
      2 -> getexp(ctx, 17, 0)
      3 -> getexp(ctx, 26, 0)
      4 -> getexp(ctx, 37, 0)
      5 -> getexp(ctx, 78, 0)
      6 -> getexp(ctx, 115, 0)
      7 -> getexp(ctx, 155, 0)
      _level -> ctx
    end
  end

  defp grant_job_experience(ctx) do
    case job_level(ctx) do
      1 -> getexp(ctx, 0, 10)
      2 -> getexp(ctx, 0, 18)
      3 -> getexp(ctx, 0, 28)
      4 -> getexp(ctx, 0, 40)
      5 -> getexp(ctx, 0, 91)
      6 -> getexp(ctx, 0, 151)
      _level -> ctx
    end
  end
end
