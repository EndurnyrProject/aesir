defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.SwordmanSkills.LeonVonFrich do
  @moduledoc """
  Leon teaches the Swordman quest skill Fatal Blow in Prontera.

  ## Behavior

  - Laughs at anyone who walks up to him.
  - Talks to Swordman-class characters at job level 25 or higher, or Knights and Crusaders,
    about his new skill and its requirements.
  - Teaches Fatal Blow in exchange for 10 Fire Arrow, 10 Silver Arrow, 1 Banana Juice,
    30 Tentacle, and 5 Royal Jelly.

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
        x: 75,
        y: 88,
        dir: 5,
        sprite: 85,
        name: "Leon Von Frich",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @fatal_blow 145

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx |> mes("[Leon]") |> mes("Hahahahahahaha!") |> mes("Hahahahahahaha!") |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if eligible?(ctx) do
      swordman_visit(ctx)
    else
      farewell(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp eligible?(ctx) do
    Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) and
      (job_level(ctx) >= 25 or
         (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) or
            Rathena.job_id(base_job(ctx)) == Rathena.job_id(:crusader)))
  end

  defp swordman_visit(ctx) do
    cond do
      getskilllv(ctx, @fatal_blow) == 1 -> greet_veteran(ctx)
      has_materials?(ctx) -> offer_skill(ctx)
      true -> praise_arm(ctx)
    end
  end

  defp has_materials?(ctx) do
    count_item(ctx, 1752) > 9 and count_item(ctx, 1751) > 9 and count_item(ctx, 532) > 0 and
      count_item(ctx, 962) > 29 and count_item(ctx, 526) > 4
  end

  defp greet_veteran(ctx) do
    ctx
    |> mes("[Leon]")
    |> mes("Eh?")
    |> mes("I was wondering who that was!")
    |> mes("Why it's you from before!")
    |> mes("Nice to see you again! How are you?")
    |> mes("Be careful! Hahaha!")
    |> close()
  end

  defp offer_skill(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Leon]")
      |> mes("Ooh! You are more than ready")
      |> mes("to learn Fatal Blow!")
      |> mes("So how about it? Would you like to learn?")
      |> next()
      |> select(["Yes!", "No, I don't want to.", "But, what is Fatal Blow?"])

    case choice do
      1 -> teach_skill(ctx)
      2 -> ctx |> mes("[Leon]") |> mes("I don't like you!!!") |> close()
      3 -> explain_skill(ctx)
      _ -> praise_arm(ctx)
    end
  end

  defp teach_skill(ctx) do
    ctx
    |> mes("[Leon]")
    |> mes("OK, lets begin!")
    |> next()
    |> delitem(1752, 10)
    |> delitem(1751, 10)
    |> delitem(532, 1)
    |> delitem(962, 30)
    |> delitem(526, 5)
    |> skill(@fatal_blow, 1, :permanent)
    |> mes("[Leon]")
    |> mes("Success!")
    |> mes("Go use your new skill to its full potential.")
    |> mes("Hahahahahahahaha!")
    |> close()
  end

  defp explain_skill(ctx) do
    ctx
    |> mes("[Leon]")
    |> mes("I developed this skill recently.")
    |> mes("When you use bash, depending ")
    |> mes("on your level, you can stun ")
    |> mes("your opponent. .")
    |> mes("You have learned bash, haven't you?")
    |> next()
    |> mes("[Leon]")
    |> mes("What do you think. Stun is")
    |> mes("a very useful technique. Don't you find this skill attractive?")
    |> mes("When you think you do, just come right back to me!")
    |> close()
  end

  defp praise_arm(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Leon]")
      |> mes("Ooh! A young and strong swordsman!")
      |> next()
      |> mes("[Leon]")
      |> mes("Wow, seeing your arm, you must enjoy using bash?")
      |> next()
      |> select(["Eh, I... just..."])

    {ctx, present} =
      ctx
      |> mes("[Leon]")
      |> arm_comment(sex(ctx) == 0)
      |> mes("In times of only useless and lazy youngsters,")
      |> mes("I'm glad I met someone strong like you.")
      |> next()
      |> mes("[Leon]")
      |> mes("Yes, I would like to give a present to an awesome swordsman like you.")
      |> next()
      |> select(["What present?", "It's ok."])

    ctx
    |> describe_present(present)
    |> pitch_skill()
  end

  defp arm_comment(ctx, true) do
    ctx
    |> mes("No need to be surprised.")
    |> mes("If you use a sword, of course you ought to have a good arm!")
  end

  defp arm_comment(ctx, false) do
    ctx
    |> mes("Nothing to be embarrassed about.")
    |> mes("Even if you are a female you need a strong arm to use a sword!")
  end

  defp describe_present(ctx, 1) do
    ctx
    |> mes("[Leon]")
    |> mes("Haha nothing special, but a skill to attack the vital point!")
    |> next()
    |> mes("[Leon]")
    |> mes("...Haha nothing special, just a skill that aims at the vital spot!")
    |> next()
  end

  defp describe_present(ctx, 2) do
    ctx
    |> mes("[Leon]")
    |> mes("...Haha nothing special, just a skill that aims at the vital spot!")
    |> next()
  end

  defp describe_present(ctx, _choice), do: ctx

  defp pitch_skill(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Leon]")
      |> mes("It's a skill I developed recently.")
      |> mes("When you use bash, depending on")
      |> mes("your level, your opponent can")
      |> mes("become stunned.")
      |> mes("You have learned bash, haven't you?")
      |> next()
      |> mes("[Leon]")
      |> mes("When I was a swordsman like you,")
      |> mes("I used to enjoy using Bash. Every time, I thought")
      |> mes("- maybe the attack would be more powerful")
      |> mes("if I use stun at the same time.")
      |> next()
      |> mes("[Leon]")
      |> mes("I drew back from the battlefield to do research")
      |> mes("and finally, I developed this wonderful new skill!")
      |> mes("Would you like to learn this skill?")
      |> next()
      |> select(["Yes.", "No.", "Do you have any advice on how to eat sushi?"])

    case choice do
      1 -> explain_requirements(ctx)
      2 -> decline(ctx)
      3 -> sushi_advice(ctx)
      _ -> farewell(ctx)
    end
  end

  defp explain_requirements(ctx) do
    ctx
    |> mes("[Leon]")
    |> mes("Ok. I'll tell you the requirements.")
    |> mes("First you need to have level 5 Bash.")
    |> mes(
      "You will also need to prepare 10 Fire Arrows, 10 Silver Arrows, 1 bottle of Banana Juice, 30 Tentacles, and 5 bottles of Royal Jelly."
    )
    |> mes("They are.. somewhat like ingredients.")
    |> next()
    |> mes("[Leon]")
    |> mes("come to me again once you have all the materials.")
    |> mes("We shall talk then.")
    |> close()
  end

  defp decline(ctx) do
    ctx
    |> mes("[Leon]")
    |> mes("Hahahahahahahahahaha!")
    |> mes("... ")
    |> mes(" ... ")
    |> mes(" ...")
    |> mes("I'm at a loss of words!?")
    |> close()
  end

  defp sushi_advice(ctx) do
    ctx
    |> mes("[Sushi King Leon]")
    |> mes("The best way to eat sushi is")
    |> mes("with your hands.")
    |> mes("That is the basic.")
    |> mes("And dip the fish, not the rice,")
    |> mes("in the soy sauce.")
    |> next()
    |> mes("[Sushi King Leon]")
    |> mes("That way you get a richer flavor.")
    |> mes("Also, always eat the kind that is in season.")
    |> mes("Eating in the order of white fish then")
    |> mes("blue fish will make it taste better!")
    |> mes("Mmm! I like sushi~~!")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Leon]")
    |> mes("Oh, no! I have nothing to offer you!")
    |> mes("I can't say nice and fun things to anyone")
    |> mes("other than swordsmen!")
    |> mes("See you in a better world!")
    |> close()
  end
end
