defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.SwordmanSkills.Juan do
  @moduledoc """
  Juan teaches the Swordman quest skill Auto Berserk in Prontera.

  ## Behavior

  - Sends Swordman-class characters below job level 30 away, unless they are Knights
    or Crusaders.
  - Teaches Auto Berserk in exchange for 35 Powder of Butterfly, 10 Horrendous Mouth,
    10 Decayed Nail, and 10 Honey.
  - Explains the skill's history to Swordmen without the materials.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Masao
    - Euphy
    - Lupus
    - Silentdragon
    - MasterOfMuppets
    - IVBela

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/swordman_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 94,
        y: 57,
        dir: 3,
        sprite: 85,
        name: "Juan",
        scope: :shared,
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @auto_berserk 146

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) do
      swordman_visit(ctx)
    else
      farewell(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp swordman_visit(ctx) do
    cond do
      getskilllv(ctx, @auto_berserk) == 1 -> greet_veteran(ctx)
      job_level(ctx) < 10 and not knight_or_crusader?(ctx) -> dismiss_beginner(ctx)
      job_level(ctx) < 30 and not knight_or_crusader?(ctx) -> dismiss_novice_swordman(ctx)
      has_materials?(ctx) -> offer_skill(ctx)
      true -> talk_about_limits(ctx)
    end
  end

  defp knight_or_crusader?(ctx) do
    Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) or
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:crusader)
  end

  defp has_materials?(ctx) do
    count_item(ctx, 924) > 34 and count_item(ctx, 958) > 9 and count_item(ctx, 957) > 9 and
      count_item(ctx, 518) > 9
  end

  defp greet_veteran(ctx) do
    ctx
    |> mes("[Juan]")
    |> mes("Mmm? Long time no see!")
    |> mes("How are you?")
    |> mes("You got stronger than before.")
    |> mes("Many expect great things from you.")
    |> mes("You can do it.")
    |> close()
  end

  defp dismiss_beginner(ctx) do
    ctx
    |> mes("[?]")
    |> mes("What are you?")
    |> mes("Eh, still a beginner.")
    |> mes("I'm busy, so go train a little more")
    |> mes("before coming back.")
    |> close()
  end

  defp dismiss_novice_swordman(ctx) do
    ctx
    |> mes("[Juan]")
    |> mes("Oh, nice to meet you.")
    |> mes("You can be on your way. (smiley~)")
    |> close()
  end

  defp offer_skill(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Juan]")
      |> mes("Ooh. Young swordsman!")
      |> mes("You are ready to learn the")
      |> mes("newest skill, Auto Berserk?!")
      |> next()
      |> select(["Hoho, I would like to learn it now.", "What is that?"])

    case choice do
      1 -> teach_skill(ctx)
      2 -> explain_skill(ctx)
      _ -> talk_about_limits(ctx)
    end
  end

  defp teach_skill(ctx) do
    ctx
    |> mes("[Juan]")
    |> mes("Ok. Then...")
    |> next()
    |> delitem(924, 35)
    |> delitem(958, 10)
    |> delitem(957, 10)
    |> delitem(518, 10)
    |> skill(@auto_berserk, 1, :permanent)
    |> mes("[Juan]")
    |> mes("You have just become a swordsman")
    |> mes("that can use Auto Berserk.")
    |> mes("You can go about ")
    |> mes("and achieve great things!")
    |> next()
    |> mes("[Juan]")
    |> mes("Good luck!")
    |> next()
    |> mes("[Juan]")
    |> mes("....................................oh yeah.")
    |> mes("I forgot to say something.")
    |> mes("There are some things you must keep in mind.")
    |> next()
    |> mes("[Juan]")
    |> mes("Once you regain health,")
    |> mes("this skill will subside.")
    |> mes("Also, there isn't really a time limit")
    |> mes("but it can still disappear when")
    |> mes("it is attacked with a skill that can")
    |> mes("nullify provoke.")
    |> next()
    |> mes("[Juan]")
    |> mes("If you don't remember these characteristics,")
    |> mes("you may run into some problems on the battlefield")
    |> mes("when the skill disappears all of a sudden.")
    |> next()
    |> mes("[Juan]")
    |> mes("Then... bye for real~")
    |> close()
  end

  defp explain_skill(ctx) do
    ctx
    |> mes("[Juan]")
    |> mes("Auto Berserk?")
    |> mes("It's a skill crucial on the battlefield.")
    |> mes("When your health is in red,")
    |> mes("your hidden potential provokes yourself")
    |> mes("to help you in battle.")
    |> next()
    |> mes("[Juan]")
    |> mes("It is perfect for those that")
    |> mes("fight on the battlefield like fire!")
    |> mes("With your ability, you can learn")
    |> mes("this skill right now.")
    |> mes("Then, I shall tell you the necessary materials.")
    |> next()
    |> mes("[Juan]")
    |> mes("You need 35 Powder of Butterfly.")
    |> mes("The energy from the magnificent")
    |> mes("wings of a butterfly will")
    |> mes("help you gather your strength!")
    |> mes("And 10 Horrendous Mouth.")
    |> mes("10 Decayed Nail.")
    |> mes("and last but not least...")
    |> mes("10 Honey!")
    |> next()
    |> mes("[Juan]")
    |> mes("Did you get all that down?")
    |> mes("As always, please come back")
    |> mes("when you are ready.")
    |> mes("I look forward to seeing you again.")
    |> close()
  end

  defp talk_about_limits(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Juan]")
      |> mes("Oh no, you have more injuries")
      |> mes("since the last time I saw you.")
      |> mes("You went into battle like this?")
      |> mes("Seems like you are straining yourself.")
      |> next()
      |> mes("[Juan]")
      |> mes("Even though you may have a lot of strength")
      |> mes("you can't do much when you reach your limits so")
      |> mes("don't overestimate your powers.")
      |> mes("Of course you could always use the")
      |> mes("skill we developed to overcome these limits.")
      |> next()
      |> select([
        "Eh! What are you talking about?",
        "Haha, there can't be such a thing.",
        "Keuuuuuuuh!"
      ])

    case choice do
      1 ->
        reveal_skill(ctx)

      2 ->
        ctx
        |> mes("[Juan]")
        |> mes("Bleh, were you fooled all your life.")
        |> mes("I don't know. Don't talk to me.")
        |> close()

      3 ->
        ctx
        |> mes("[Juan]")
        |> mes("Keuuuuuuuuuuuuuh!")
        |> mes("Ooowwwwwuuuuuuuuuuuuuhhh!")
        |> mes("Keuaaaaaaaaaaah!")
        |> close()

      _ ->
        farewell(ctx)
    end
  end

  defp reveal_skill(ctx) do
    ctx
    |> mes("[Juan]")
    |> mes("The skill is called Berserk.")
    |> mes("It is deemed the flower of a battlefield.")
    |> mes("When your health is red,")
    |> mes("your hidden potential is provokes yourself")
    |> mes("to help you in battle.")
    |> next()
    |> mes("[Juan]")
    |> mes("It is perfect for those that")
    |> mes("fight on the battlefield like fire!")
    |> mes("With your ability, you can learn")
    |> mes("this skill right now.")
    |> mes("Then, I shall tell you the necessary materials.")
    |> next()
    |> mes("[Juan]")
    |> mes("You need 35 Powder of Butterfly.")
    |> mes("The energy from the magnificent")
    |> mes("wings of a butterfly will")
    |> mes("help you gather your strength!")
    |> mes("And 10 Horrendous Mouth.")
    |> mes("10 Decayed Nail.")
    |> mes("and last but not least...")
    |> mes("10 Honeys!")
    |> next()
    |> mes("[Juan]")
    |> mes("Did you get all that down?")
    |> mes("As always, please come back")
    |> mes("when you are ready.")
    |> mes("I look forward to seeing you again.")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Juan]")
    |> mes("Are you enjoying your trip?")
    |> mes("I hope you have nice days ahead of you.")
    |> mes("Ah, I am just a kind knight Juan.")
    |> mes("Don't worry about me too much. Hahaha...")
    |> close()
  end
end
