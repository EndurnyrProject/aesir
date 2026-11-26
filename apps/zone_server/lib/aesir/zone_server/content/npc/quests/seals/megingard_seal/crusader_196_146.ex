defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.Crusader196146 do
  @moduledoc """
  Jack O, a former 1st Squad Crusader now recruiting Swordmen, recalls the dispute during his
  squad's final mission for the Megingard Seal quest.

  ## Behavior

  - Outside the Megingard seal phase, he invites Swordmen to become Crusaders and tells other
    players about the doll the girl in front of him wants.
  - Once the player has traced the 1st Squad, he only vaguely remembers his old leader.
  - Told what the squad records say about the final mission, he denies the insubordination, and
    the quest advances.
  - Asked about his old leader afterwards, he describes the leader's arrogance and the dispute
    over a godly artifact, and the quest advances; later he repeats it and chews Green Herbs.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 196,
        y: 146,
        dir: 0,
        sprite: 751,
        name: "Crusader",
        scope: :shared,
        unique_name: "Crusader#megin2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
         get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      quest_talk(ctx)
    else
      recruit_talk(ctx)
    end
  end

  defp quest_talk(ctx) do
    eremes = get_char_var(ctx, :god_eremes, 0)

    cond do
      eremes == 18 -> vague_menu(ctx)
      eremes > 18 -> memories_talk(ctx)
      true -> ctx |> hey_kid() |> close2()
    end
  end

  defp vague_menu(ctx) do
    {ctx, choice} =
      ctx
      |> yawn()
      |> next()
      |> mes("[Jack O]")
      |> mes("Eh...?")
      |> next()
      |> select([
        "Ask him about Rebarev Doug.",
        "Ask him how he's been doing.",
        "Ask him about the last mission of the 1st Squad."
      ])

    case choice do
      1 ->
        ctx
        |> old_leader()
        |> close()

      2 ->
        ctx
        |> mes("[Jack O]")
        |> mes("Me? Yeah, I'm always busy recruiting future Crusaders.")
        |> mes("We always welcome Swordmen")
        |> mes("of great ability!")
        |> next()
        |> mes("[Jack O]")
        |> mes("How does it sound? Why don't you volunteer to become a Crusader?")
        |> close()

      3 ->
        ctx
        |> mes("[Jack O]")
        |> mes("Last mission?")
        |> mes("Eh, I don't really remember it.")
        |> close()

      _ ->
        ctx
    end
  end

  defp memories_talk(ctx) do
    case get_char_var(ctx, :god_megin_3, 0) do
      megin when megin == 0 or megin == 1 ->
        memories_menu(ctx)

      2 ->
        ctx
        |> mes("[Jack O]")
        |> mes("Our old leader was")
        |> mes("so arrogant to the point")
        |> mes("of being a little off his rocker.")
        |> next()
        |> mes("[Jack O]")
        |> mes("I mean, normal people")
        |> mes(
          "don't say things like '^0000FFI am the most religious man in the universe! Kneel before me!^000000' Yeah. Not a normal thing to say."
        )
        |> next()
        |> mes("[Jack O]")
        |> mes("Anyway, if the squad")
        |> mes(
          "leader punished anyone for insubordination, I'm sure that it was unwarranted. I don't remember too much, but I'm sure of that."
        )
        |> next()
        |> mes("[Jack O]")
        |> mes("Excuse me, I need to take some Green Herbs. Taking these seems")
        |> mes("to be the only thing that works for my headache.")
        |> next()
        |> mes("^3355FFJack O busily chewed")
        |> mes("on some Green Herbs.")
        |> mes("It seemed to greatly relieve him from the pain of his headaches.^000000")
        |> close()

      _ ->
        ctx
        |> yawn()
        |> close()
    end
  end

  defp memories_menu(ctx) do
    {ctx, choice} =
      ctx
      |> yawn()
      |> next()
      |> mes("[Jack O]")
      |> mes("Eh...?")
      |> next()
      |> select([
        "Ask him about Rebarev Doug.",
        "Ask him how he's been doing.",
        "Ask about 1st Squad's final mission."
      ])

    case choice do
      1 ->
        ask_about_leader(ctx)

      2 ->
        ctx
        |> mes("[Jack O]")
        |> mes(
          "Me? Yeah, I'm not doing so bad. Keeping busy recruiting future Crusaders. We welcome all"
        )
        |> mes("Swordmen if they show potential~")
        |> close()

      3 ->
        ctx
        |> mes("[Jack O]")
        |> mes("Huh...?")
        |> mes("Why would")
        |> mes("you want to know?")
        |> next()
        |> mes(
          "^3355FFYou tell him what you've read in the records for the 1st Squad. Afterwards, Jack O looks a little confused.^000000"
        )
        |> next()
        |> mes("[Jack O]")
        |> mes("Huh...?")
        |> mes("I might not be able to remember")
        |> mes(
          "a whole lot from back then, but the part about ^0000FFinsubordination^000000 can't be right. I'm sure of that."
        )
        |> deny_insubordination()
        |> close()

      _ ->
        ctx
    end
  end

  defp deny_insubordination(ctx) do
    if get_char_var(ctx, :god_megin_3, 0) == 0,
      do: set_char_var(ctx, :god_megin_3, 1),
      else: ctx
  end

  defp ask_about_leader(ctx) do
    if get_char_var(ctx, :god_megin_3, 0) == 1 do
      ctx
      |> mes("[Jack O]")
      |> mes("Ah right. Our old leader.")
      |> mes("Now I remember: He was")
      |> mes("a pretty self righteous jerk")
      |> mes("now that I think about it!")
      |> next()
      |> mes("[Jack O]")
      |> mes(
        "Can you believe he used to say that ^0000FFno one is more religious than him in this world^000000?! That's egoism right there. And maybe insanity."
      )
      |> next()
      |> mes("[Jack O]")
      |> mes("Anyway, everyone in the squad")
      |> mes("took pride in their faith. When")
      |> mes("you're having a rough time in the")
      |> mes("real world, you depend on religion, you know?")
      |> next()
      |> mes("[Jack O]")
      |> mes("Anyways, in the records about")
      |> mes(
        "our squad, it says that one of us was punished for insubordination, rebelling or something. That's"
      )
      |> mes("a complete lie.")
      |> next()
      |> mes("[Jack O]")
      |> mes("During our final mission,")
      |> mes(
        "our old leader had a huge argument with one us over something we found. I remember it being some kind of godly artifact, but I can't clearly remember what it was."
      )
      |> next()
      |> mes("[Jack O]")
      |> mes(
        "Although there was an obvious dispute, I think it was our squad leader who was out of line."
      )
      |> mes("I... I can't really say...")
      |> next()
      |> mes("[Jack O]")
      |> mes("I can't for the life of me")
      |> mes("remember how the guy who")
      |> mes("argued with the squad leader")
      |> mes("looked like. The higher-ups")
      |> mes("musta did something to me...")
      |> next()
      |> mes("[Jack O]")
      |> mes(
        "Anyway, I know for sure that whatever that guy did, it wasn't insubordination. In fact, I think he might've been right!"
      )
      |> next()
      |> mes("[Jack O]")
      |> mes("That's all I can remember.")
      |> mes(
        "I better take some Green Herbs now. My head throbs like crazy whenever I think about that time."
      )
      |> set_char_var(:god_megin_3, 2)
      |> close()
    else
      ctx
      |> old_leader()
      |> close()
    end
  end

  defp recruit_talk(ctx) do
    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) do
      ctx
      |> hey_kid()
      |> next()
      |> mes("[Jack O]")
      |> mes(
        "Basically, you'd be volunteering to be part of our military, as well as train for the Holy War."
      )
      |> next()
      |> mes("[Jack O]")
      |> mes(
        "If you have some faith and know how to wield a sword, you'll be more than welcome here."
      )
      |> next()
      |> mes("[Jack O]")
      |> mes("Just think about my suggestion")
      |> mes("and come back if you're interested. Alright then, see you later~")
      |> close()
    else
      ctx
      |> yawn()
      |> next()
      |> mes("[Jack O]")
      |> mes("Huh...?")
      |> mes(
        "Are you interested in knowing more about Crusaders? Hahaha, I guess that must be the case."
      )
      |> next()
      |> mes("[Jack O]")
      |> mes("By the way, bring a doll to")
      |> mes(
        "the kid in front of me. If you're lucky, she'll give you something neat in return. What it is, I don't know. I've got no dolls."
      )
      |> next()
      |> mes("[Jack O]")
      |> mes(
        "In accordance with the Crusader code, I'm not supposed to lie. So yeah, you can trust me!"
      )
      |> close2()
    end
  end

  defp yawn(ctx) do
    ctx
    |> mes("[Jack O]")
    |> mes("^333333*Yawn...*^000000")
    |> mes(
      "It's quiet and boring, as per usual. Let's see if there's any Swordmen I can recruit today."
    )
  end

  defp hey_kid(ctx) do
    ctx
    |> mes("[Jack O]")
    |> mes("Hey kid!")
    |> mes("Ever think about")
    |> mes("bein' a Crusader?")
  end

  defp old_leader(ctx) do
    ctx
    |> mes("[Jack O]")
    |> mes(
      "Ah! Yeah, our old leader back in the 1st Squad. Heh. I haven't seen him since we were disbanded."
    )
  end
end
