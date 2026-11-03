defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.CrusaderSkills.Soldier do
  @moduledoc """
  Sloutii, a wounded Crusader Guardian patrolling south of Geffen, who teaches Shrink to the
  Crusader who saves his life.

  ## Behavior

  - Hands over his patrol report once the player treats his wounds with a Red Potion.
  - Collapses while the player fetches Father Arthur's antidote.
  - Each antidote dose works with a 2 in 5 chance; on success he teaches Shrink, otherwise the
    player must return to Father Arthur for a fresh dose.
  - Warns everyone else about the Goblins in the area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gef_fild13",
        x: 297,
        y: 242,
        dir: 3,
        sprite: 751,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#277"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @shrink 1002
  @red_potion 501

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:crusader) do
      paladin_with_shrink? = upper(ctx) == 1 and Rathena.truthy?(getskilllv(ctx, @shrink))
      step = get_char_var(ctx, :CRUS_SK, 0)

      case {paladin_with_shrink?, step} do
        {true, 8} -> recuperating(ctx)
        {true, 10} -> ask_about_shrink(ctx)
        _ -> patrol_quest(ctx, step)
      end
    else
      warn_about_goblins(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp patrol_quest(ctx, 1), do: found_wounded(ctx)

  defp patrol_quest(ctx, 2) do
    if count_item(ctx, @red_potion) > 0, do: give_red_potion(ctx), else: in_too_much_pain(ctx)
  end

  defp patrol_quest(ctx, 3), do: deliver_report(ctx)
  defp patrol_quest(ctx, 4), do: ctx |> mes("[Sloutii]") |> collapse() |> close()
  defp patrol_quest(ctx, 5), do: ctx |> mes("[Sloutii]") |> worsening() |> close()
  defp patrol_quest(ctx, 6), do: ctx |> mes("[Sloutii]") |> unconscious() |> close()
  defp patrol_quest(ctx, 7), do: administer_antidote(ctx)
  defp patrol_quest(ctx, step) when step in [8, 10], do: friendly_greeting(ctx)
  defp patrol_quest(ctx, 9), do: antidote_failed(ctx)
  defp patrol_quest(ctx, _step), do: warn_about_goblins(ctx)

  defp recuperating(ctx) do
    ctx
    |> mes("[Sloutii]")
    |> mes("Hey pal, it's been")
    |> mes("a while. I still need")
    |> mes("to recuperate from my")
    |> mes("wounds, so if you want")
    |> mes("to learn Shrink, speak")
    |> mes("to Sir Ford, alright?")
    |> close()
  end

  defp ask_about_shrink(ctx) do
    ctx
    |> mes("[Sloutii]")
    |> mes("So how's that Shrink")
    |> mes("skill working out for you?")
    |> mes("Hopefully, it's saved your")
    |> mes("life as many times as it's")
    |> mes("saved mine. Anyway, I'll")
    |> mes_player_name("see you around, ", "~")
    |> close()
  end

  defp found_wounded(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes("Arrrrrghhh!")
    |> mes("M-my legs!")
    |> mes("What the hell")
    |> mes("have they done")
    |> mes("to my legs?!")
    |> next()
    |> mes_player_name()
    |> mes("Wh-what happened?")
    |> mes("Were you attacked?")
    |> next()
    |> mes("[Soldier]")
    |> mes("Y-yeah, I was on my way")
    |> mes("to report to Sir Ford on my")
    |> mes("regular patrol when I was")
    |> mes("attacked by these Goblins!")
    |> mes("I've got to warn my superiors!")
    |> mes("They're going to raid Geffen!")
    |> next()
    |> mes_player_name()
    |> mes("I actually spoke to")
    |> mes("Sir Ford! You must be")
    |> mes("Sloutii, right? He sent me")
    |> mes("to see what happened to you!")
    |> next()
    |> mes("[Sloutii]")
    |> mes("Great, p-perfect timing!")
    |> mes("Listen, you've got to send")
    |> mes("him this report. I-it contains")
    |> mes("details of my patrol and an")
    |> mes("urgent request for backup.")
    |> mes("U-ugh! We don't have time!")
    |> next()
    |> mes_player_name()
    |> mes("Wait...!")
    |> mes("But what about")
    |> mes("you? You're hurt...")
    |> next()
    |> mes("[Sloutii]")
    |> mes("I'll be damned if help")
    |> mes("is delayed on my account!")
    |> mes("Just hurry and get that")
    |> mes("report to Sir Ford! Now go!")
    |> mes("Now, if I can just get that")
    |> mes("report out of my-- OW! N-no...")
    |> next()
    |> mes_player_name()
    |> mes("^333333(He's writhing in pain")
    |> mes("so much that he can't even")
    |> mes("give me his report. I better")
    |> mes("bring him a Red Potion to")
    |> mes("alleviate his suffering...)^000000")
    |> set_char_var(:CRUS_SK, 2)
    |> close()
  end

  defp give_red_potion(ctx) do
    ctx
    |> mes_player_name()
    |> mes("Here, please take")
    |> mes("this Red Potion.")
    |> mes("It just might help...")
    |> next()
    |> mes("[Sloutii]")
    |> mes("Oh, thank goodness!")
    |> mes("Arrrgh! Just pour it")
    |> mes("into the wound! I-it...")
    |> mes("It burns so much! Those")
    |> mes("Goblins must've cut me with")
    |> mes("something coated in poison!")
    |> next()
    |> mes("[Sloutii]")
    |> mes("Ah... Ahh...")
    |> mes("The bleeding hasn't")
    |> mes("stopped, but at least")
    |> mes("it's better. Here, take")
    |> mes("this report now and get it")
    |> mes("to Sir Ford. Hurry and go!")
    |> next()
    |> mes("^3355FFYou received Sloutii's")
    |> mes("patrol report. Some of the")
    |> mes("pages are smudged with")
    |> mes("the blood from his wound.^000000")
    |> delitem(@red_potion, 1)
    |> set_char_var(:CRUS_SK, 3)
    |> close()
  end

  defp in_too_much_pain(ctx) do
    ctx
    |> mes("[Sloutii]")
    |> mes("Hurry and t-take this")
    |> mes("report! L-let me just")
    |> mes("hand it to you and th--")
    |> mes("Arrrrgh! I-I can't move!")
    |> mes("It... It just hurts so much!")
    |> next()
    |> mes_player_name()
    |> mes("^333333(I better bring him")
    |> mes("a Red Potion, otherwise")
    |> mes("I have no hope of getting")
    |> mes("that report without hurting him!)")
    |> close()
  end

  defp deliver_report(ctx) do
    ctx
    |> mes("[Sloutii]")
    |> mes("We're running out")
    |> mes("of time! Hurry and get")
    |> mes("my report to Sir Ford as")
    |> mes("soon as you possibly can!")
    |> close()
  end

  defp worsening(ctx) do
    if upper(ctx) == 1, do: collapse(ctx), else: unconscious(ctx)
  end

  defp collapse(ctx) do
    ctx
    |> mes("Eeearrrgh--!")
    |> mes("My l-legs! Everything")
    |> mes("is starting to h-hurt!")
    |> next()
    |> mes("^3355FFSloutii fell unconscious,")
    |> mes("and it seems that the wounds")
    |> mes("in his legs are causing him")
    |> mes("much more suffering.^000000")
  end

  defp unconscious(ctx) do
    ctx
    |> mes("........")
    |> mes(".........")
    |> next()
    |> mes("^3355FFSloutii is still")
    |> mes("unconscious. He'll")
    |> mes("die if his injuries aren't")
    |> mes("treated immediately.")
    |> mes("You'll have to help him")
    |> mes("as quickly as you can.^000000")
  end

  defp administer_antidote(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou carefully pour the")
      |> mes("Goblin poison antidote")
      |> mes("into Sloutii's mouth.")
      |> mes("His throat struggles to")
      |> mes("swallow the antidote, but")
      |> mes("he manages to ingest it.^000000")
      |> next()

    if Enum.random(1..5) in [1, 5], do: teach_shrink(ctx), else: antidote_wore_off(ctx)
  end

  defp teach_shrink(ctx) do
    ctx
    |> mes("^3355FFMiraculously, the wounds")
    |> mes("inflicted by the Goblins")
    |> mes("begin to rapidly heal.^000000")
    |> next()
    |> mes("[Sloutii]")
    |> mes("Oh, wh-what happened?")
    |> mes("Am... Am I really still alive?")
    |> mes("Hey, it's you! You must've")
    |> mes("saved my life! I thought")
    |> mes("I was going to die for sure!")
    |> next()
    |> mes_player_name()
    |> mes("Well, it's a good thing")
    |> mes("I came in time. Sir Ford")
    |> mes("had me visit Father Arthur to")
    |> mes("make an antidote to save you.")
    |> mes("Ah, and I already delivered")
    |> mes("your report to Sir Ford.")
    |> next()
    |> mes("[Sloutii]")
    |> mes("Great! Now, let me repay you")
    |> mes("by teaching you a special skill")
    |> mes("developed by the Prontera Crusader Guardians. Using this skill helped")
    |> mes("me survive the attack by those")
    |> mes("Goblins. You ready to learn?")
    |> next()
    |> mes("[Sloutii]")
    |> mes("This skill is called")
    |> mes("''^0000FFShrink^000000,'' and it will")
    |> mes("knock enemies backwards")
    |> mes("when you successfully")
    |> mes("guard their attacks.")
    |> next()
    |> mes("[Sloutii]")
    |> mes("Now listen closely...")
    |> mes("To execute it, you've got")
    |> mes("to be able to concentrate")
    |> mes("and repel enemies using")
    |> mes("the right stance and mindset...")
    |> next()
    |> mes("[Sloutii]")
    |> mes("Great! You learned the")
    |> mes("skill! Now, I hope you use")
    |> mes("this ability to combat evil")
    |> mes("and protect the weak. Ah, and")
    |> mes("if I learn any new skills, I'll be sure to teach you right away.")
    |> set_char_var(:CRUS_SK, 8)
    |> skill(@shrink, 1, :permanent)
    |> close()
  end

  defp antidote_wore_off(ctx) do
    ctx
    |> mes("^3355FFUnfortunately, nothing")
    |> mes("happened. The antidote")
    |> mes("proabably lost its effect")
    |> mes("while you were traveling")
    |> mes("from Father Arthur to Sloutii.")
    |> mes("You've got to return to Father")
    |> mes("Arthur and make another one.^000000")
    |> set_char_var(:CRUS_SK, 9)
    |> close()
  end

  defp friendly_greeting(ctx) do
    ctx
    |> mes("[Sloutii]")
    |> mes("Hey, it's you~")
    |> mes("So how have you been?")
    |> mes("If you ever get some free")
    |> mes("time, come by and maybe")
    |> mes("we can practice our swordplay.")
    |> close()
  end

  defp antidote_failed(ctx) do
    ctx
    |> mes("^3355FFThe antidote you")
    |> mes("previously administered")
    |> mes("had no effect. You've got")
    |> mes("to try again by returning to")
    |> mes("Father Arthur and making")
    |> mes("a new antidote for Sloutii.^000000")
    |> close()
  end

  defp warn_about_goblins(ctx) do
    ctx
    |> mes("[Sloutii]")
    |> mes("Please be careful around")
    |> mes("this area. Goblins are known")
    |> mes("to attack any humans that")
    |> mes("they encounter. And lately,")
    |> mes("they've been getting even more violent, so stay on the lookout.")
    |> close()
  end

  defp mes_player_name(ctx, prefix \\ "[", suffix \\ "]"),
    do: mes(ctx, Rathena.concat(Rathena.concat(prefix, char_name(ctx, 0)), suffix))
end
