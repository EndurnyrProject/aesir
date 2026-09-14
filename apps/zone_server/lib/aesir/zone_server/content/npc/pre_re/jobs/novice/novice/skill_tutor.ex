defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.SkillTutor do
  @moduledoc """
  Teaches novice skill fundamentals and awards the First Aid skill.

  ## Behavior

  - Explains skill use, skill points, and basic novice abilities.
  - Grants lesson experience and First Aid while recording course progress.
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
        x: 83,
        y: 111,
        dir: 3,
        sprite: 753,
        name: "Skill Tutor",
        unique_name: "Skill Tutor#nv"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      essential_courses_complete?(ctx) -> completed_courses_menu(ctx)
      get_char_var(ctx, :nov_get_item03, 0) < 10 -> offer_skill_lesson(ctx)
      get_char_var(ctx, :nov_get_item02, 0) < 10 -> direct_to_interfaces_tutor(ctx)
      get_char_var(ctx, :nov_get_item04, 0) < 10 -> direct_to_item_tutor(ctx)
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
         |> mes("[Cecil]")
         |> mes("Huh...?")
         |> mes("Did you need more help?")
         |> mes(
           "I see that you've completed all the essential courses. Did you speak to the assistant tutors too?"
         )
         |> next()
         |> select(["Send me to the next course!", "Assistant tutors?", "Take me to a town!"]) do
      {ctx, 1} ->
        ctx
        |> mes("[Cecil]")
        |> mes("Ah! Right, right.")
        |> mes("You've got to take on the Field Combat Training Course sometime, I suppose.")
        |> next()
        |> mes("[Cecil]")
        |> mes(
          "Man, I'm so jealous of the instructors in the Field Combat Training Course. Teaching basic information is just soooo not as cool as beating stuff up."
        )
        |> next()
        |> mes("[Cecil]")
        |> mes("Ah, right.")
        |> mes("Field Combat.")
        |> mes("I'm sending you now.")
        |> mes("Good luck, kid!")
        |> close()
        |> warp("new_1-2", 28, 178)

      {ctx, 2} ->
        ctx
        |> mes("[Cecil]")
        |> mes("You know about the")
        |> mes("assistant tutors, don't you?")
        |> next()
        |> mes("[Cecil]")
        |> mes(
          "Listen. The three of tutors in this room only teach the most basic information. The courses we teach are meant to be passed quickly."
        )
        |> next()
        |> mes("[Cecil]")
        |> mes(
          "But some people might benefit a little bit more if they learned some more detailed information."
        )
        |> next()
        |> mes("[Cecil]")
        |> mes(
          "If you're completely new to Ragnarok, it couldn't hurt to attend the classes held by the assistant tutors at least once."
        )
        |> next()
        |> mes("[Cecil]")
        |> mes(
          "A guy named Leo Handerson seems to know a lot about skills, so I think his knowledge would be useful to you."
        )
        |> close()

      {ctx, 3} ->
        ctx
        |> mes("[Cecil]")
        |> mes("A town...?")
        |> mes("What do I look like, your own personal Peco Peco?")
        |> next()
        |> mes("[Cecil]")
        |> mes(
          "That's right, you might be too young to know about that. Listen, if you want to move to a town, speak to the Kafra Lady to the right, okay?"
        )
        |> close()

      {ctx, _choice} ->
        ctx
    end
  end

  defp offer_skill_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Cecil]")
      |> mes(char_name(ctx, 0))
      |> mes("Heh, I like your name!")
      |> renew_expired_registration()

    case ctx
         |> mes("Then, shall we begin the class?")
         |> next()
         |> select(["What do you teach?", "I want Field Combat Training now!", "Cancel"]) do
      {ctx, 1} -> skill_lesson(ctx)
      {ctx, 2} -> send_to_field_combat(ctx)
      {ctx, 3} -> ctx |> emotion(:huk) |> close()
      {ctx, _choice} -> ctx
    end
  end

  defp renew_expired_registration(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :NEW_MES_FLAG0, 0)) do
      ctx
      |> mes("By the way, your proof of registration has expired, so let me give you a new one.")
      |> mes("Let me give you a new one.")
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

  defp skill_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Cecil]")
      |> mes("I live for power")
      |> mes("and die for power!")
      |> mes("I shall teach you")
      |> mes("my famous fatal blow!")
      |> next()
      |> mes("[Cecil]")
      |> mes("I'm just pulling your chain!")
      |> mes("I actually just teach you how to use your skills. I still live for power, though.")
      |> next()
      |> mes("[Cecil]")
      |> mes(
        "In your Basic Info Window, click the ^3355FFSkill^000000 button to open your Skill Window. You can also press the '^3355FFAlt^000000' and '^3355FFS^000000' keys at the same time."
      )
      |> next()
      |> mes("[Cecil]")
      |> mes("When your")
      |> mes("Skill Window is open,")
      |> mes("you'll see an icon labeled")
      |> mes("'^3355FFBasic Skill^000000.'")
      |> explain_skill_points()
      |> next()
      |> mes("[Cecil]")
      |> mes(
        "So did you distribute the skill points to your Basic Skills? You'll need to master the Basic Skills eventually, so it's a good idea."
      )
      |> next()
      |> mes("[Cecil]")
      |> mes(
        "For more detailed information on skills, go speak to Leo Handerson, one of the assistant tutors."
      )
      |> next()
      |> mes("[Cecil]")
      |> mes("Oh, I almost forgot!")
      |> mes(
        "Let me teach you the ^3355FFFirst Aid^000000 skill. This skill will help you out a lot when you're in danger."
      )
      |> next()
      |> mes("^3355FFYou have learned")
      |> mes("the ^4A708BFirst Aid^3355FF skill.^000000")
      |> skill(142, 1, :permanent)
      |> set_char_var(:NOV_SK, 3)
      |> set_char_var(:nov_get_item03, 11)
      |> next()
      |> grant_second_job_experience()
      |> next()
      |> mes("[Cecil]")
      |> mes("Now, open your Skill Window")
      |> mes(
        "and check if you have the ^3355FFFirst Aid^000000 skill icon. To use it, you need to double-click that skill icon."
      )
      |> mes("Now, try it!")
      |> percent_heal(hp: -50, sp: 0)
      |> next()
      |> mes("[Cecil]")
      |> mes(
        "Active skills, like First Aid, require a certain amount of SP to use them. The First Aid skill is useful for Novices, since it refills a little bit of HP."
      )
      |> next()
      |> mes("[Cecil]")
      |> mes("You've been")
      |> mes("a good student,")
      |> mes("so let me reward you!")
      |> grant_base_reward()

    case ctx
         |> next()
         |> mes("[Cecil]")
         |> mes(
           "Well, that's it for the essential fundamentals. If you want a more comprehensive lesson, you gotta speak to the assistant tutors."
         )
         |> next()
         |> select(["Okay.", "Send me to Field Combat Training, now!", "Cancel"]) do
      {ctx, 1} ->
        ctx
        |> mes("[Cecil]")
        |> mes("Everyone in the")
        |> mes("Training Grounds is")
        |> mes("more than willing to")
        |> mes("help you. Good luck!")
        |> close()

      {ctx, 2} ->
        send_to_field_combat(ctx)

      {ctx, 3} ->
        ctx |> emotion(:huk) |> close()

      {ctx, _choice} ->
        ctx
    end
  end

  defp explain_skill_points(ctx) do
    if job_level(ctx) < 7 do
      ctx
      |> next()
      |> mes("[Cecil]")
      |> mes(
        "Now, at the bottom of the Skill Window, the number of remaining Skill Points that you have is displayed."
      )
      |> next()
      |> mes("[Cecil]")
      |> mes(
        "Open your Skill Window ('Alt' + 'S') and click the '^3355FFLv Up^000000' button next to the Basic Skill icon to allocate a Skill Point to your Basic Skills."
      )
      |> set_char_var(:nov_get_item03, 10)
      |> grant_job_experience()
    else
      ctx
      |> next()
      |> mes("[Cecil]")
      |> mes(
        "Huh. Actually, your Job Level is higher that I thought. I guess you already know the basics about skills then."
      )
    end
  end

  defp grant_second_job_experience(ctx) do
    if job_level(ctx) < 7 do
      ctx
      |> mes("^3355FFYou have gained a small")
      |> mes("amount of Job experience.^000000")
      |> set_char_var(:nov_get_item03, 12)
      |> grant_job_experience()
    else
      ctx
    end
  end

  defp grant_base_reward(ctx) do
    if base_level(ctx) < 8 do
      ctx
      |> mes("Behold: bonus experience!")
      |> set_char_var(:nov_get_item03, 13)
      |> grant_base_experience()
    else
      ctx
      |> next()
      |> mes("[Cecil]")
      |> mes("Oh wait. You're much higher in level than I thought. Still, I'm proud of you!")
    end
  end

  defp direct_to_interfaces_tutor(ctx) do
    case ctx
         |> mes("[Cecil]")
         |> mes("So how may")
         |> mes("I help you?")
         |> mes(
           "Whoa, you haven't attended the Basic Interface class yet? Oh well, I know that class is kinda boring~"
         )
         |> next()
         |> select([
           "Oh, I better take that class.",
           "Send me to Field Combat Training.",
           "Cancel"
         ]) do
      {ctx, 1} ->
        ctx
        |> mes("[Cecil]")
        |> mes(
          "Yeah, that's a good idea. After all, you'll gain experience and items while you take that class. Alright then, the Interfaces Tutor is in the center of this room. Go for it~"
        )
        |> close()

      {ctx, 2} ->
        send_to_field_combat(ctx)

      {ctx, 3} ->
        ctx |> emotion(:huk) |> close()

      {ctx, _choice} ->
        ctx
    end
  end

  defp direct_to_item_tutor(ctx) do
    case ctx
         |> mes("[Cecil]")
         |> mes("So how may")
         |> mes("I help you?")
         |> mes(
           "Whoa, you haven't attended the Item Information class yet? Oh well, I know that class is kinda boring~"
         )
         |> next()
         |> select([
           "Oh, I better take that class.",
           "Send me to Field Combat Training.",
           "Cancel"
         ]) do
      {ctx, 1} ->
        ctx
        |> mes("[Cecil]")
        |> mes(
          "Yeah, that's a good idea. After all, you'll gain experience and items while you take that class. Alright then, the Item Tutor is on the far right side of this room. Go for it~"
        )
        |> close()

      {ctx, 2} ->
        send_to_field_combat(ctx)

      {ctx, 3} ->
        ctx |> emotion(:huk) |> close()

      {ctx, _choice} ->
        ctx
    end
  end

  defp send_to_field_combat(ctx) do
    ctx
    |> mes("[Cecil]")
    |> mes("Heh heh~!")
    |> mes(
      "Alright, practice makes perfect! Let me send you to the guys at Field Combat Training. Take care!"
    )
    |> close()
    |> warp("new_1-2", 28, 178)
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
