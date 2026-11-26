defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OldSoldier do
  @moduledoc """
  A retired soldier recounts the fate of a fallen warrior.

  ## Behavior

  - The emerald investigation leads to the warrior's story and a choice about the jewel.
  - Returning the jewel awards items and experience according to level and timing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prontera", x: 140, y: 304, dir: 5, sprite: 901, name: "Old Soldier", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 -> overweight(ctx)
      get_char_var(ctx, :jewel_nd, 0) == 25 -> ask_about_battles(ctx)
      get_char_var(ctx, :jewel_nd, 0) > 25 and get_char_var(ctx, :jewel_nd, 0) < 29 -> regret(ctx)
      get_char_var(ctx, :jewel_nd, 0) == 29 -> ask_about_spirit(ctx)
      get_char_var(ctx, :jewel_nd, 0) == 30 -> return_jewel(ctx, :later)
      get_char_var(ctx, :jewel_nd, 0) == 31 -> completed(ctx)
      true -> greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overweight(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("Why are you carrying")
    |> mes("so much stuff with you?")
    |> mes("Isn't there a Kafra Storage")
    |> mes("service for keeping your junk?")
    |> close()
  end

  defp ask_about_battles(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Retired Soldier]")
      |> mes("It's strange that so")
      |> mes("many people have been")
      |> mes("wanting to talk to me for")
      |> mes("some reason, but I'll")
      |> mes("admit that it's kind of nice.")
      |> next()
      |> select(["Ask About Past Battles", "Ask About Fallen Warrior"])

    case choice do
      1 -> past_battles(ctx)
      2 -> fallen_warrior(ctx)
      _ -> ctx
    end
  end

  defp past_battles(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("Don't get me started.")
    |> mes("Once I start talking about")
    |> mes("the old days, I'll go on all")
    |> mes("night. Those were real hard")
    |> mes("times to live through, but good")
    |> mes("memories to remember...")
    |> close()
  end

  defp fallen_warrior(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("The fallen warrior...?")
    |> mes("There's only one that brings")
    |> mes("a chill down my spine whenever")
    |> mes("I think of him. He was about")
    |> mes("your age when it happened...")
    |> next()
    |> mes("[Retired Soldier]")
    |> mes("We received a report about")
    |> mes("a Cobold threat, so we were")
    |> mes("dispatched to the fields")
    |> mes("west of Geffen. But the")
    |> mes("battle was over once we")
    |> mes("arrived. We were too late.")
    |> next()
    |> mes("[Retired Soldier]")
    |> mes("All the Cobolds were slain,")
    |> mes("but... There was one warrior")
    |> mes("left, covered in blood. When")
    |> mes("he saw us, he just started")
    |> mes("attacking everyone! He")
    |> mes("had completely lost it.")
    |> next()
    |> mes("[Retired Soldier]")
    |> mes("We had no choice but to")
    |> mes("kill him. It was self defense,")
    |> mes("but I can't help but pity him.")
    |> mes("All his comrades had been")
    |> mes("killed: I can't imagine how")
    |> mes("that must have felt.")
    |> next()
    |> mes("[Retired Soldier]")
    |> mes("We arrived too late to")
    |> mes("see that battle, but I'm")
    |> mes("pretty sure it was horrific.")
    |> mes("You must be pretty interested")
    |> mes("in learning about this soldier.")
    |> next()
    |> mes("[Retired Soldier]")
    |> mes("Well, I'm just glad that you")
    |> mes("were able to know more")
    |> mes("about this story. There's")
    |> mes("much you can learn from")
    |> mes("other people's experiences.")
    |> set_char_var(:jewel_nd, 26)
    |> close()
  end

  defp regret(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("I don't regret that we")
    |> mes("had to kill that warrior.")
    |> mes("We did had we had to")
    |> mes("back in those days.")
    |> close()
  end

  defp ask_about_spirit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Retired Soldier]")
      |> mes("Oh, it's you again.")
      |> mes("Did you want to ask me")
      |> mes("more about that warrior?")
      |> mes("I'm afraid I already told")
      |> mes("you everything I know.")
      |> next()
      |> select(["Sorry...", "I met the warrior's spirit."])

    case choice do
      1 -> ctx |> mes("[Retired Soldier]") |> mes("It's fine.") |> close()
      2 -> discuss_spirit(ctx)
      _ -> ctx
    end
  end

  defp discuss_spirit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Retired Soldier]")
      |> mes("What? How is that")
      |> mes("even possible?")
      |> next()
      |> mes("^3355FFYou explain to the")
      |> mes("retired soldier everything")
      |> mes("that has happened so far.^000000")
      |> next()
      |> mes("[Retired Soldier]")
      |> mes("That's quite a story.")
      |> mes("Still, I'm surprised that")
      |> mes("he didn't want to talk to")
      |> mes("you about what happened.")
      |> mes("I guess he still harbors")
      |> mes("bad feelings about that day...")
      |> next()
      |> mes("[Retired Soldier]")
      |> mes("Well, I guess it doesn't")
      |> mes("really matter now. Chalk")
      |> mes("this all up to a really good")
      |> mes("learning experience.")
      |> next()
      |> select([
        "I feel so sorry for him.",
        "Do you believe the jewel is really cursed?"
      ])

    case choice do
      1 -> sympathy(ctx)
      2 -> discuss_curse(ctx)
      _ -> ctx
    end
  end

  defp sympathy(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("Well...")
    |> mes("I don't know what to tell")
    |> mes("you. I mean, you can't really")
    |> mes("put the blame on anybody.")
    |> mes("He just lost his mind...")
    |> close()
  end

  defp discuss_curse(ctx) do
    ctx =
      ctx
      |> mes("[Retired Soldier]")
      |> mes("I'm not really sure if the")
      |> mes("jewel was cursed, if that")
      |> mes("warrior started the curse,")
      |> mes("or if the jewel isn't cursed")
      |> mes("at all. I'm just an old,")
      |> mes("simple soldier.")
      |> next()
      |> mes("[Retired Soldier]")
      |> mes("One thing's for sure:")
      |> mes("if there was a curse, that")
      |> mes("soldier should have been")
      |> mes("able to overcome it if his will")
      |> mes("was strong enough. It's harsh")
      |> mes("to say it like this, but...")
      |> next()
      |> mes("[Retired Soldier]")
      |> mes("True warriors have the")
      |> mes("strength to endure, to")
      |> mes("fight temptation, to keep")
      |> mes("their focus. That guy...")
      |> mes("He wasn't cut out to fight.")
      |> set_char_var(:jewel_nd, 30)
      |> next()

    if count_item(ctx, 7725) > 0 do
      ctx |> offer_jewel() |> award_jewel(:immediate)
    else
      ctx |> offer_jewel() |> close()
    end
  end

  defp return_jewel(ctx, timing) do
    if count_item(ctx, 7725) > 0 do
      award_jewel(ctx, timing)
    else
      ctx |> offer_jewel() |> close()
    end
  end

  defp offer_jewel(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("You know what?")
    |> mes("If you're so worried")
    |> mes("about a curse, why don't")
    |> mes("you leave that jewel with me?")
    |> mes("Don't worry, I'll make sure")
    |> mes("to compensate you for it.")
    |> next()
    |> mes("[Retired Soldier]")
    |> mes("I'd rather keep it to myself,")
    |> mes("rather than risk it messing")
    |> mes("around with other people.")
    |> mes("I know my will's tough enough")
    |> mes("to resist its curse, you know,")
    |> mes("if it actually exists.")
  end

  defp award_jewel(ctx, timing) do
    ctx = ctx |> delitem(7725, 1) |> set_char_var(:jewel_nd, 31) |> give_item(603, 1)
    renewal = Rathena.truthy?(checkre(ctx, 3))
    level = base_level(ctx)

    ctx =
      cond do
        level < 66 -> give_item(ctx, 607, 1)
        level >= if(renewal, do: 275, else: 99) -> give_item(ctx, 617, 1)
        true -> getexp(ctx, experience(level, renewal, timing), 0)
      end

    final_advice(ctx)
  end

  defp experience(level, true, timing) do
    cond do
      level < 75 -> 5_000
      level < 81 and timing == :immediate -> 18_000
      level < 81 -> 8_000
      level < 86 and timing == :immediate -> 36_000
      level < 86 -> 15_000
      level < 91 and timing == :immediate -> 50_000
      level < 91 -> 20_000
      level < 96 and timing == :immediate -> 80_000
      level < 96 -> 40_000
      timing == :immediate -> 100_000
      true -> 50_000
    end
  end

  defp experience(level, false, timing) do
    cond do
      level < 75 -> 50_000
      level < 81 and timing == :immediate -> 180_000
      level < 81 -> 80_000
      level < 86 and timing == :immediate -> 360_000
      level < 86 -> 150_000
      level < 91 and timing == :immediate -> 500_000
      level < 91 -> 200_000
      level < 96 and timing == :immediate -> 800_000
      level < 96 -> 400_000
      timing == :immediate -> 1_000_000
      true -> 500_000
    end
  end

  defp final_advice(ctx) do
    ctx
    |> next()
    |> mes("[Retired Soldier]")
    |> mes("If there's anything")
    |> mes("you learn from all this,")
    |> mes("it's that you should never")
    |> mes("succumb to your desperation.")
    |> mes("Rage gives you nothing:")
    |> mes("its power is an illusion.")
    |> close()
  end

  defp completed(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("Well, you learned all there")
    |> mes("is to know about the Unlucky")
    |> mes("Emerald. It's time you forget")
    |> mes("about the curse or whatever,")
    |> mes("and find new adventures.")
    |> mes("Ah, to be young again...")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Retired Soldier]")
    |> mes("Ah, how I long for")
    |> mes("the old days. Being")
    |> mes("retired is just so...")
    |> mes("It's so boring! I guess")
    |> mes("it's time to find a hobby.")
    |> close()
  end
end
