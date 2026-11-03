defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.CrusaderSkills.Ford do
  @moduledoc """
  Leslie Ford, commander of the Prontera Crusader Guardians, who starts and tracks the Shrink
  skill quest for Crusaders.

  ## Behavior

  - Asks Crusaders to fetch a missing patrol report from Sloutii, south of Geffen.
  - On receiving the report, sends the player to Prontera Church for a Goblin poison antidote.
  - Reminds the player of the current step and thanks them once Sloutii is saved.
  - Re-teaches Shrink to Paladins who completed the quest but lost the skill on rebirth.
  - Turns away non-Crusaders.

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
        map: "geffen",
        x: 110,
        y: 117,
        dir: 3,
        sprite: 752,
        name: "Ford",
        scope: :shared,
        unique_name: "Ford#11"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @shrink 1002

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:crusader) do
      step = get_char_var(ctx, :CRUS_SK, 0)

      if step == 8 and getskilllv(ctx, @shrink) == 0,
        do: reteach_paladin(ctx),
        else: crusader_quest(ctx, step)
    else
      excuse_himself(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp crusader_quest(ctx, 0), do: request_report(ctx)
  defp crusader_quest(ctx, 1), do: find_sloutii(ctx)
  defp crusader_quest(ctx, 2), do: return_for_report(ctx)
  defp crusader_quest(ctx, 3), do: read_report(ctx)
  defp crusader_quest(ctx, 4), do: get_antidote(ctx)
  defp crusader_quest(ctx, step) when step in [5, 6], do: hurry_to_arthur(ctx)
  defp crusader_quest(ctx, 8), do: farewell(ctx)
  defp crusader_quest(ctx, 10), do: welcome_back(ctx)
  defp crusader_quest(ctx, _step), do: deliver_antidote(ctx)

  defp reteach_paladin(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Hey, it's been a while~")
    |> mes("And you even managed to")
    |> mes("become a Paladin. You must")
    |> mes("have forgotten how to perform")
    |> mes("the Shrink skill, so I'll teach")
    |> mes("it to you real quick... There!")
    |> set_char_var(:CRUS_SK, 10)
    |> skill(@shrink, 1, :permanent)
    |> close()
  end

  defp request_report(ctx) do
    ctx =
      ctx
      |> mes("[Ford]")
      |> mes("Damn! Why is it")
      |> mes("taking so long?")
      |> mes("Ah, finally, you've")
      |> mes("arrived! Quick, show me")
      |> mes("the ^FF0000report^000000 you've brought!")
      |> next()
      |> mes_player_name("[", "]")
      |> mes("Excuse me...?")
      |> mes("Oh, you must have")
      |> mes("mistaken me for someone")
      |> mes("else. I really don't know")
      |> mes("what you're talking about.")
      |> next()
      |> mes("[Ford]")
      |> mes("What?! You're not one")
      |> mes("of the guards stationed")
      |> mes("at South Geffen? Oh, this")
      |> mes("is horrible. I apologize,")
      |> mes("I just assumed since you")

    {ctx, choice} =
      ctx
      |> mes(dressed_like(ctx))
      |> next()
      |> mes_player_name("[", "]")
      |> mes("I'm sorry...")
      |> mes("What's happening?")
      |> mes("Is something the matter?")
      |> mes("I'm an adventurer that")
      |> mes_player_name("goes by the name, ", ".")
      |> next()
      |> mes("[Ford]")
      |> mes("Well, I'm Leslie Ford,")
      |> mes("commander of the Prontera")
      |> mes("Crusader Guardians. We're")
      |> mes("charged with the duty of")
      |> mes("protecting adventurers and")
      |> mes("citizens from evil monsters.")
      |> next()
      |> mes("[Ford]")
      |> mes("There's been a recent surge")
      |> mes("in unprovoked violence from")
      |> mes("Goblins and they're making")
      |> mes("quite a bit of trouble for us.")
      |> mes("Our patrols are supposed to")
      |> mes("report on their activity to me.")
      |> next()
      |> mes("[Ford]")
      |> mes("However, today's report")
      |> mes("hasn't arrived yet, so I'm")
      |> mes("starting to fear that something")
      |> mes("has happened to the patrol.")
      |> mes("Unfortunately, my duties don't")
      |> mes("allow me to leave my post.")
      |> next()
      |> mes("[Ford]")
      |> mes("I'm getting desperate,")
      |> mes("and I don't have any choice")
      |> mes("but to ask for outside help.")
      |> mes("Since you're a fellow Crusader,")
      |> mes("I want to ask you if you would")
      |> mes("please lend me your aid.")
      |> next()
      |> select(["Sure.", "I'm sorry, but I'm busy..."])

    case choice do
      1 ->
        ctx
        |> mes("[Ford]")
        |> mes("Great, thank you so much!")
        |> mes("Now, please go and seek")
        |> mes("out ^0000FFSloutii^000000 who should be")
        |> mes("stationed south of Geffen,")
        |> mes("and deliver his report to me.")
        |> mes("Your help is a great relief...")
        |> set_char_var(:CRUS_SK, 1)
        |> close()

      2 ->
        ctx
        |> mes("[Ford]")
        |> mes("Hm. I understand.")
        |> mes("I do not know what")
        |> mes("obligations that you")
        |> mes("have right now, but if")
        |> mes("your current task isn't")
        |> mes("urgent, please reconsider...")
        |> close()

      _ ->
        close(ctx)
    end
  end

  defp dressed_like(ctx) do
    if upper(ctx) == 1,
      do: "were dressed like a Paladin...",
      else: "were dressed like a Crusader..."
  end

  defp find_sloutii(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Please search for")
    |> mes("^0000FFSloutii^000000 in the area south")
    |> mes("of Geffen, and he should")
    |> mes("give you his report on")
    |> mes("his patrol of the Goblins")
    |> mes("for you to deliver to me.")
    |> close()
  end

  defp return_for_report(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Wait, you've met with")
    |> mes("Sloutii, but haven't")
    |> mes("received his report?")
    |> mes("Please go back to him")
    |> mes("and bring it to me, it's")
    |> mes("imperative that I read it!")
    |> close()
  end

  defp read_report(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Ah, you've returned!")
    |> mes("So how is Sloutii?")
    |> mes("Is everything all right?")
    |> next()
    |> mes_player_name("[", "]")
    |> mes("Here, I've brought")
    |> mes("this report as soon as")
    |> mes("I could! You better read")
    |> mes("it, quick! Things seemed")
    |> mes("pretty bad when I left...")
    |> next()
    |> mes("[Ford]")
    |> mes("Goodness, there's blood all")
    |> mes("over the paper! Let's see...")
    |> mes("Oh no. This is an emergency")
    |> mes("situation! I need to report this to Sir Arga and request for")
    |> mes("backup immediately!")
    |> next()
    |> mes_player_name("[", "]")
    |> mes("Wait, we need to do")
    |> mes("something about Sloutii.")
    |> mes("He was wounded by the")
    |> mes("Goblins, and I think he's")
    |> mes("in serious trouble.")
    |> next()
    |> mes("[Ford]")
    |> mes("The Goblins...?")
    |> mes("Oh no, you'll need the")
    |> mes("special antidote that you")
    |> mes("can get from Father Arthur")
    |> mes("to treat the poison in the")
    |> mes("knives these Goblins use.")
    |> next()
    |> mes("[Ford]")
    |> mes("While I request for backup,")
    |> mes("please go to ^0000FFProntera Church^000000")
    |> mes("and ask Father ^0000FFArthur^000000 for his")
    |> mes("antidote for Goblin Poison.")
    |> mes("If you don't hurry, it might")
    |> mes("be too late for Sloutii--!")
    |> set_char_var(:CRUS_SK, 4)
    |> close()
  end

  defp get_antidote(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Please hurry and obtain")
    |> mes("the antidote for Goblin's")
    |> mes("poison from ^0000FFFather Arthur^000000")
    |> mes("in ^0000FFProntera Church^000000. Sloutii's")
    |> mes("life depends on you now.")
    |> close()
  end

  defp hurry_to_arthur(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("You've already met")
    |> mes("Father Arthur? Good,")
    |> mes("now please hurry and")
    |> mes("get the antidote from him.")
    |> mes("Without it, Sloutii will slowly")
    |> mes("and excruciatingly perish!")
    |> close()
  end

  defp deliver_antidote(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Great, you've received")
    |> mes("the antidote from Father")
    |> mes("Arthur! Now, make haste")
    |> mes("and administer it to Sloutii")
    |> mes("stationed south of Geffen.")
    |> mes("Hurry, every second counts!")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("I hear that you were")
    |> mes("able to save Sloutii.")
    |> mes("For that, I am eternally")
    |> mes("grateful. We could use more")
    |> mes("people like you to serve in the")
    |> mes("Prontera Crusader Guardians...")
    |> next()
    |> mes("[Ford]")
    |> mes("I know that you adventurers")
    |> mes("prefer not to commit to these")
    |> mes("kinds of organizations, but")
    |> mes("your help will always be")
    |> mes("welcome here. I hope to")
    |> mes("see you again someday.")
    |> next()
    |> mes("[Ford]")
    |> mes("Thanks once again,")
    |> mes("and I hope to that you")
    |> mes("travel in safety. For now,")
    |> mes_player_name("this is farewell, ", ".")
    |> close()
  end

  defp welcome_back(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Hey, it's been a while~")
    |> mes("You should come by more")
    |> mes("often, and if you're really")
    |> mes("interested, you can enlist in")
    |> mes("my troops. We can really use")
    |> mes("somebody with your expertise.")
    |> close()
  end

  defp excuse_himself(ctx) do
    ctx
    |> mes("[Ford]")
    |> mes("Ah, greetings.")
    |> mes("I'm sorry that I cannot")
    |> mes("assist you, adventurer,")
    |> mes("but I have something")
    |> mes("rather urgent to take care")
    |> mes("of. Now if you'll excuse me...")
    |> close()
  end

  defp mes_player_name(ctx, prefix, suffix),
    do: mes(ctx, Rathena.concat(Rathena.concat(prefix, char_name(ctx, 0)), suffix))
end
