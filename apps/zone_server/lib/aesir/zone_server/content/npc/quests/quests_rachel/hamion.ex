defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Hamion do
  @moduledoc """
  Helps an adventurer forge a Wind Hammer to free Maheo.

  ## Behavior

  - Requests the ingredients needed to forge the hammer.
  - Exchanges the ingredients for the hammer and advances the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 265,
        y: 98,
        dir: 3,
        sprite: 930,
        name: "Hamion",
        scope: :shared,
        unique_name: "Hamion#aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{908, 200}]) == 0 do
      too_heavy(ctx)
    else
      discuss_quest(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp discuss_quest(ctx) do
    quest = get_char_var(ctx, :ice_necklace_q, 0)

    cond do
      quest < 2 -> greeting(ctx) |> close()
      quest == 2 -> request_ingredients(ctx)
      quest == 3 -> prepare_hammer(ctx)
      quest >= 4 -> relaxing(ctx)
      true -> ctx
    end
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Hamion]")
    |> mes("Hm? Did you need")
    |> mes("something? If it's not too")
    |> mes("important, then I'd like to")
    |> mes("get back to reading my book.")
  end

  defp request_ingredients(ctx) do
    ctx = ctx |> greeting() |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Um, would you know")
    |> mes("a mage by the name")
    |> mes("of Maheo? I'm supposed")
    |> mes("to go look for his master")
    |> mes("around this area.")
    |> next()
    |> mes("[Hamion]")
    |> mes("Well, you've found him")
    |> mes("because that would be me.")
    |> mes("What happened to Maheo?")
    |> next()
    |> mes("[Hamion]")
    |> mes("He froze himself?!")
    |> mes("Hahahaha! Some genius!")
    |> mes("Oh, well, I suppose he still")
    |> mes("has plenty to learn about")
    |> mes("character, if not magic.")
    |> next()
    |> mes("[Hamion]")
    |> mes("Let's see, let's see...")
    |> mes("This book ought to have")
    |> mes("the answer. Mmm... Ah!")
    |> mes("Page 42! I need to construct")
    |> mes("an artifact in order to break")
    |> mes("that mystical ice. Mmm.")
    |> next()
    |> mes("[Hamion]")
    |> mes("Would you help")
    |> mes("me? I need to get")
    |> mes("^4D4DFF5 Rough Winds^000000,")
    |> mes("^4D4DFF1 Hammer^000000, and")
    |> mes("^4D4DFF1 Blank Scroll^000000")
    |> next()
    |> mes("[Hamion]")
    |> mes("You can get Blank Scrolls")
    |> mes("in the Sage Academy in Juno.")
    |> mes("Ah, and the Hammer is a weapon,")
    |> mes("not one of those smithing tools.")
    |> mes("I'd help you if I could, but...")
    |> mes("I'm just smart, not strong.")
    |> set_char_var(:ice_necklace_q, 3)
    |> changequest(2110, 2111)
    |> close()
  end

  defp prepare_hammer(ctx) do
    if count_item(ctx, 996) < 5 or count_item(ctx, 1354) < 1 or
         count_item(ctx, 7433) < 1 do
      ctx
      |> mes("[Hamion]")
      |> mes("I need to create")
      |> mes("a magical artifact")
      |> mes("to break the ice that's")
      |> mes("trapping Maheo. Would you")
      |> mes("please help me? There's no")
      |> mes("way I can get the items myself!")
      |> next()
      |> mes("[Hamion]")
      |> mes("I need to get")
      |> mes("^4D4DFF5 Rough Winds^000000,")
      |> mes("^4D4DFF1 Hammer^000000, and")
      |> mes("^4D4DFF1 Blank Scroll^000000")
      |> next()
      |> mes("[Hamion]")
      |> mes("You can get Blank Scrolls")
      |> mes("in the Sage Academy in Juno.")
      |> mes("Ah, and the Hammer is a weapon,")
      |> mes("not one of those smithing tools.")
      |> mes("I'd help you if I could, but...")
      |> mes("I'm just smart, not strong.")
      |> close()
    else
      forge_hammer(ctx)
    end
  end

  defp forge_hammer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hamion]")
      |> mes("Great, you have everything")
      |> mes("I need! But first, would you")
      |> mes("make sure that you only have")
      |> mes("1 Hammer in your inventory?")
      |> mes("If you have more than one,")
      |> mes("I might take the wrong Hammer.")
      |> next()
      |> select(["Let me check.", "Don't worry, I checked."])

    if choice == 1 do
      ctx
      |> mes("[Hamion]")
      |> mes("Alright, it's always")
      |> mes("better to be safe than")
      |> mes("sorry! If only Maheo was")
      |> mes("a little more careful, more")
      |> mes("like you are, then maybe this")
      |> mes("wouldn't have happened.")
      |> close()
    else
      ctx
      |> mes("[Hamion]")
      |> mes("Okay, I'll take your")
      |> mes("word for it. Now, let's")
      |> mes("bring the artifact forging")
      |> mes("process. Hmmm... Let me")
      |> mes("review it here on page 45.")
      |> next()
      |> mes("[Hamion]")
      |> mes("Here we go...!")
      |> next()
      |> specialeffect2(:cone)
      |> mes("^3355FF*Pzzzz*^000000")
      |> next()
      |> mes("[Hamion]")
      |> mes("...Aaaand now it's done.")
      |> mes("Here, take this Wind Hammer")
      |> mes("and use it to free Maheo.")
      |> mes("This hammer will only work")
      |> mes("once, so make sure that you")
      |> mes("smash that ice properly!")
      |> delitem(1354, 1)
      |> delitem(996, 5)
      |> delitem(7433, 1)
      |> set_char_var(:ice_necklace_q, 4)
      |> changequest(2111, 2112)
      |> give_item(7569, 1)
      |> close()
    end
  end

  defp relaxing(ctx) do
    ctx
    |> mes("[Hamion]")
    |> mes("There are always")
    |> mes("singing birds and")
    |> mes("flitting butterflies")
    |> mes("all over this place")
    |> mes("It's so relaxing, and")
    |> mes("such a great place to read.")
    |> close()
  end
end
