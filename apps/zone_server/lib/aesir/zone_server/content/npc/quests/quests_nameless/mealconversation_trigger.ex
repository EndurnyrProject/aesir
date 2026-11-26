defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.MealconversationTrigger do
  @moduledoc """
  A restaurant conversation gives a traveler a clue about Veins.

  ## Behavior

  - The encounter advances the investigation and charges for the meal when the player has enough zeny.

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
      %{
        map: "ra_in01",
        x: 301,
        y: 43,
        dir: 0,
        sprite: -1,
        name: "MealConversation Trigger",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 -> overweight(ctx)
      get_char_var(ctx, :aru_monas, 0) == 7 -> meal_conversation(ctx)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp meal_conversation(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Waiter]")
      |> mes("What would you like to order?")
      |> mes("Our special today is Fried")
      |> mes("Veins Stripe Stickleback")
      |> mes("since we received some")
      |> mes("high quality fish from Veins")
      |> mes("just this morning.")
      |> next()
      |> select(["...Yes, that sounds good."])

    ctx =
      ctx
      |> mes("[Waiter]")
      |> mes("Excellent choice.")
      |> mes("Just to let you know,")
      |> mes("that dish is ^9932CD3,000 zeny^000000.")
      |> mes("I'll be right back.")
      |> next()
      |> mes("^3355FFThe waiter took your")
      |> mes("order, and left to go to")
      |> mes("the kitchen. You decide to")
      |> mes("eavesdrop on the people")
      |> mes("talking at the next table")
      |> mes("while you're waiting.^000000")
      |> next()
      |> mes("[Husky Male Voice]")
      |> mes("...............................")
      |> mes("I really saw it, the greatest")
      |> mes("fish in the world! Last time")
      |> mes("I went to Veins, I glimpsed")
      |> mes("the Veins Golden Stripe")
      |> mes("Stickleback! It's true!")
      |> next()
      |> mes("[Gloomy Male Voice]")
      |> mes("So were you able to taste")
      |> mes("that Veins Golden Stripe")
      |> mes("Stickleback juice?")
      |> next()
      |> mes("[Average Male Voice]")
      |> mes("Aw man, if I did, that")
      |> mes("would've been a once")
      |> mes("in a lifetime experience!")
      |> mes("Veins Golden Stripe")
      |> mes("Sticklebacks are only")
      |> mes("caught once a decade!")
      |> next()
      |> mes("[Husky Male Voice]")
      |> mes("Oh yeah, that juice is")
      |> mes("incredible. My voice even")
      |> mes("changed after I drank it!")
      |> mes("It was just... So profound.")
      |> next()
      |> mes("[Average Male Voice]")
      |> mes("Oh! So that's why")
      |> mes("you sound different.")
      |> next()
      |> mes("[Gloomy Male Voice]")
      |> mes("How did you get to drink")
      |> mes("such rare juice? I mean,")
      |> mes("there must be tons of people")
      |> mes("in line with reservations,")
      |> mes("just waiting to drink it!")
      |> next()
      |> mes("[Husky Male Voice]")
      |> mes("I got damn lucky: I went")
      |> mes("to this tavern in Veins, and")
      |> mes("overheard that ^DB7093a group of")
      |> mes("smugglers were arrested")
      |> mes("by the guards at the")
      |> mes("southeast beach^000000.")
      |> next()
      |> mes("[Husky Male Voice]")
      |> mes("Then I started thinking:")
      |> mes("maybe the smugglers were")
      |> mes("fishing. So I checked the")
      |> mes("beach to see if I could")
      |> mes("find their fishing boat.")
      |> next()
      |> mes("[Average Male Voice]")
      |> mes("Man, you must be obsessed")
      |> mes("with food. I mean, how else")
      |> mes("would you figure out that the")
      |> mes("smugglers were illegally")
      |> mes("fishing so quickly?")
      |> next()
      |> mes("[Husky Male Voice]")
      |> mes("Ha, I guess you're right!")
      |> mes("Anyway, there was only one")
      |> mes("fishing boat, and the guards")
      |> mes("were inspecting it. I was about")
      |> mes("to turn back in disappointment")
      |> mes("but then... I saw a fisherman!")
      |> next()
      |> mes("[Husky Male Voice]")
      |> mes("Out of the corner of my eye,")
      |> mes("I saw him bringing in his")
      |> mes("catch for the day, Veins")
      |> mes("Golden Strip Stickleback!")
      |> mes("I bought all of his fish")
      |> mes("right then and there.")
      |> next()
      |> mes("[Gloomy Male Voice]")
      |> mes("Boy, were you lucky.")
      |> mes("And you never hesitate")
      |> mes("to splurge when it comes")
      |> mes("to food, do you? Heh heh~")
      |> next()
      |> mes("[Husky Male Voice]")
      |> mes("Oh, that wasn't even a")
      |> mes("splurge. I'm sure you guys")
      |> mes("would do the same thing")
      |> mes("if you were in my situation.")
      |> mes("I'm just grateful that I was")
      |> mes("able to taste such rare fish.")
      |> next()
      |> mes("^3355FF...............................")
      |> mes("Then, the men started")
      |> mes("to compliment each other.^000000")
      |> next()
      |> mes("[Waiter]")
      |> mes("Ah, here's your Fried")
      |> mes("Veins Stripe Stickleback.")
      |> mes("Please enjoy your meal.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("^ff0000Veins^000000, huh? I might want")
      |> mes("to check that place one")
      |> mes("of these days to see if")
      |> mes("I can find more of this fish.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Whoa, this fish tastes...")
      |> mes("I've never tasted anything")
      |> mes("like it! It's almost like")
      |> mes("a dessert. God, it's good!")
      |> set_char_var(:aru_monas, 8)

    ctx =
      if zeny(ctx) > 3000 do
        ctx |> pay_zeny(3000) |> give_item(12052, 4)
      else
        ctx
      end

    close(ctx)
  end
end
