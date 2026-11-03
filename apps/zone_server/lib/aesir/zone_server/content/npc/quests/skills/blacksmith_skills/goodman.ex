defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.BlacksmithSkills.Goodman do
  @moduledoc """
  Goodman, a Blacksmith Guild skill master in Geffen, teaches the Greed quest skill.

  ## Behavior

  - Talks shop only with Blacksmiths and Master Smiths.
  - Offers the Greed quest, asking the smith to fill their inventory until a 500 weight item no
    longer fits.
  - Teaches Greed once the inventory is full enough, marking the quest complete.
  - Restores Greed to transcended smiths who completed the quest before rebirth, and to any
    finished smith who lacks the skill.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
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
        x: 172,
        y: 52,
        dir: 1,
        sprite: 826,
        name: "Goodman",
        scope: :shared,
        unique_name: "Goodman#qsk_bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @greed 1013

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:blacksmith) do
      not_blacksmith(ctx)
    else
      talk(ctx, upper(ctx) == 1, get_char_var(ctx, :BLACK_SK2, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk(ctx, true, 2), do: remind_transcended(ctx)
  defp talk(ctx, true, 3), do: traveling_advice(ctx)
  defp talk(ctx, master?, 0), do: offer_quest(ctx, master?)
  defp talk(ctx, master?, 1), do: check_inventory(ctx, master?)
  defp talk(ctx, _master?, _step), do: after_quest(ctx)

  defp not_blacksmith(ctx) do
    ctx
    |> mes("[Goodman]")
    |> mes("I feel like exploring")
    |> mes("the mountains to look for")
    |> mes("rare and interesting items")
    |> mes("that I can use in forging.")
    |> mes("For me, that's the greatest")
    |> mes("pleasure of being a Blacksmith.")
    |> close()
  end

  defp remind_transcended(ctx) do
    ctx
    |> mes("[Goodman]")
    |> mes("Ah, I see that you have")
    |> mes("transcended. It gladdens me")
    |> mes("to see Blacksmiths become")
    |> mes("Master Smiths for the sake")
    |> mes("of improving their craft.")
    |> next()
    |> mes("[Goodman]")
    |> mes("Hm? You've forgotten the")
    |> mes("Greed skill? You should")
    |> mes("remember how to use it now:")
    |> mes("just looking at me should")
    |> mes("jog the memories you require")
    |> mes("to use this skill once again~")
    |> ensure_greed()
    |> set_char_var(:BLACK_SK2, 3)
    |> close()
  end

  defp traveling_advice(ctx) do
    ctx
    |> mes("[Goodman]")
    |> mes("How is your forging")
    |> mes("technique coming along?")
    |> mes("When the craft frustrates you,")
    |> mes("traveling will offer a good")
    |> mes("opportunity to relax, think,")
    |> mes("and collect materials.")
    |> ensure_greed()
    |> close()
  end

  defp offer_quest(ctx, master?) do
    {ctx, choice} =
      ctx
      |> mes("[Goodman]")
      |> mes("Hey. I'm a Blacksmith")
      |> mes("skill master sent from the")
      |> mes("Blacksmith Guild. Everyone")
      |> mes("calls me Goodman. You're")
      |> mes(if master?, do: "a Master Smith, aren't you?", else: "a Blackmith, aren't you?")
      |> mes("Pffft, rhetorical question.")
      |> next()
      |> mes("[Goodman]")
      |> mes("Good news. I'm in charge of")
      |> mes("teaching the skill, developed")
      |> mes("by the Blacksmith and Merchant")
      |> mes("Guilds, called ^FF0000Greed^000000. It's your")
      |> mes("choice whether you learn it,")
      |> mes("but I recommend that you do.")
      |> next()
      |> mes("[Goodman]")
      |> mes("If you want, I can start")
      |> mes("teaching you the Greed")
      |> mes("skill right now. So what")
      |> mes("do you say, kid?")
      |> next()
      |> select(["Sounds good!", "Maybe later~"])

    if choice == 1, do: start_quest(ctx), else: decline(ctx)
  end

  defp start_quest(ctx) do
    ctx
    |> mes("[Goodman]")
    |> mes("Heh! Good choice. Now,")
    |> mes("the Greed skill automatically")
    |> mes("picks up all items in a 5*5")
    |> mes("cell area around the caster.")
    |> mes("It's handy for picking up clumps of goods from looting monsters.")
    |> next()
    |> mes("[Goodman]")
    |> mes("First thing's first. I need to")
    |> mes("test you and see if you qualify")
    |> mes("to learn this skill. Go fill your Inventory with any items until")
    |> mes("it's so full, you can't put an")
    |> mes("item of 500 Weight in it.")
    |> next()
    |> mes("[Goodman]")
    |> mes("When you finish that")
    |> mes("task, come back and")
    |> mes("talk to me. Alright")
    |> mes("then, good luck~")
    |> set_char_var(:BLACK_SK2, 1)
    |> close()
  end

  defp decline(ctx) do
    ctx
    |> mes("[Goodman]")
    |> mes("I see. It's good to be")
    |> mes("busy with other things,")
    |> mes("but remember that time is ")
    |> mes("a commodity, and you should")
    |> mes("always spend it doing the most")
    |> mes("worthwhile stuff. Understand?")
    |> close()
  end

  defp check_inventory(ctx, master?) do
    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) >= 5000 do
      too_early(ctx)
    else
      teach(ctx, master?)
    end
  end

  defp too_early(ctx) do
    ctx
    |> mes("[Goodman]")
    |> mes("Hm. You've come back")
    |> mes("too early. And you didn't")
    |> mes("complete the objective that")
    |> mes("I set for you. Listen carefully.")
    |> next()
    |> mes("[Goodman]")
    |> mes("Go fill your Inventory")
    |> mes("with any items until it")
    |> mes("becomes too full to place")
    |> mes("an item of 500 weight into it.")
    |> mes("When you finish this task,")
    |> mes("come back and report to me.")
    |> close()
  end

  defp teach(ctx, master?) do
    smiths = if master?, do: "Master Smiths", else: "Blacksmiths"

    ctx
    |> mes("[Goodman]")
    |> mes("Back already, eh?")
    |> mes("Alright, let me check")
    |> mes("the things you're carrying.")
    |> mes("Let's see, Inventory, Inventory...")
    |> next()
    |> mes("[Goodman]")
    |> mes("Good work: you pass.")
    |> mes("Do you realize now that the")
    |> mes("time and experience spent in")
    |> mes("gathering these items is worth")
    |> mes("more than their prices in zeny?")
    |> next()
    |> mes("[Goodman]")
    |> mes("I believe that #{smiths}")
    |> mes("should first and foremost be")
    |> mes("artisans. Being rich and famous")
    |> mes("is merely a side effect of that.")
    |> mes("Honorable #{smiths} know value is in the craftsmanship...")
    |> next()
    |> demonstrate(master?)
    |> mes("[Goodman]")
    |> mes("The skill you learned is")
    |> mes("called Greed, but I hope")
    |> mes("you use it in a manner that")
    |> mes("is different than its name.")
    |> mes("Don't forget that, and I hope")
    |> mes("you craft true masterpieces.")
    |> skill(@greed, 1, :permanent)
    |> set_char_var(:BLACK_SK2, if(master?, do: 4, else: 2))
    |> close()
  end

  defp demonstrate(ctx, false), do: ctx

  defp demonstrate(ctx, true) do
    ctx
    |> mes("[Goodman]")
    |> mes("Now, if you don't place too")
    |> mes("much importance on an item's")
    |> mes("worth in terms of zeny, you'll")
    |> mes("be able to let go of them much")
    |> mes("more easily. Watch me do this.")
    |> mes("See? Now you can do it too.")
    |> next()
  end

  defp after_quest(ctx) do
    ctx
    |> mes("[Goodman]")
    |> mes("How have you been using")
    |> mes("the Greed skill? Hopefully,")
    |> mes("it has been convenient in")
    |> mes("your efforts to forge goods")
    |> mes("of greater quality for all")
    |> mes("of your comrades.")
    |> ensure_greed()
    |> close()
  end

  defp ensure_greed(ctx) do
    if getskilllv(ctx, @greed) == 0, do: skill(ctx, @greed, 1, :permanent), else: ctx
  end
end
