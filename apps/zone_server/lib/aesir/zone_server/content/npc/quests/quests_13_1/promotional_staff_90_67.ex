defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.PromotionalStaff9067 do
  @moduledoc """
  The Geffen promotional staff, who runs the Emerald and Ruby stages of the Ash-Vacuum
  recruitment.

  ## Behavior

  - Runs one stage of the recruitment per `ep13_ryu` step: the shared pitch on step 0, the
    Emerald request on step 3 (quest 10059 to 10060), the Emerald delivery on step 4 (quest
    10060 to 10061), the Ruby delivery on step 5 (quest 10061 to 10062) and the Izlude
    directions on step 6.
  - Past step 6 asks how the adventure is going.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 90,
        y: 67,
        dir: 3,
        sprite: 100,
        name: "Promotional Staff",
        scope: :shared,
        unique_name: "Promotional Staff#gef"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @emerald 721
  @ruby 723

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      step when step > 6 -> already_adventuring(ctx)
      6 -> go_to_izlude(ctx)
      5 -> ruby_delivery(ctx)
      4 -> emerald_delivery(ctx)
      3 -> first_stone_request(ctx)
      _step -> shared_pitch(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp already_adventuring(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("Did you take the test?")
    |> mes("Or are you already enjoying your adventure?")
    |> close()
  end

  defp go_to_izlude(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("You didn't visit ^FF0000Izlude^000000, did you?")
    |> mes("Or do you have any business in Geffen?")
    |> close()
  end

  defp ruby_delivery(ctx) do
    if count_item(ctx, @ruby) == 0 do
      missing_ruby(ctx)
    else
      takes_ruby(ctx)
    end
  end

  defp missing_ruby(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("^FF00001 Ruby!!^000000.")
    |> mes("Don't you forget it!")
    |> mes("Hurry up! Time is zeny!")
    |> close()
  end

  defp takes_ruby(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("Wow, you brought a genuine Jewel.")
    |> mes("You are absolutely qualified.")
    |> mes("I can tell these things.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Am I exaggerating?")
    |> mes("It's true that you're")
    |> mes("considerably strong.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Ok! My job is done.")
    |> mes("Good job!!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Next step is Izlude!")
    |> mes("You can get tested by the Promotional Staff there.")
    |> mes("Hurry up!")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("The unknown place...")
    |> mes(
      "It is a very dangerous place so you must go through these tests before we can send you...."
    )
    |> mes("We're pretty picky.")
    |> next()
    |> delitem(@ruby, 1)
    |> changequest(10061, 10062)
    |> set_char_var(:ep13_ryu, 6)
    |> mes("[Promotional Staff]")
    |> mes("I hope you can do it!")
    |> mes("Good luck!")
    |> close()
  end

  defp emerald_delivery(ctx) do
    if count_item(ctx, @emerald) == 0 do
      missing_emerald(ctx)
    else
      takes_emerald(ctx)
    end
  end

  defp missing_emerald(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("The one you should bring me is")
    |> mes("^FF0000Emerald^000000. Can you get it?")
    |> close()
  end

  defp takes_emerald(ctx) do
    ctx
    |> mes("[Promotional Staff]")
    |> mes("You brought it so soon!")
    |> mes("You're a real adventurer!")
    |> mes("I will accept this Emerald as evidence.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("This isn't something I wanted to keep for myself.")
    |> mes("You know that, right?")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Next bring me ^FF00001 Ruby^000000.")
    |> mes("I can't judge you with only one jewel.")
    |> mes("So I need one more stone.")
    |> next()
    |> delitem(@emerald, 1)
    |> changequest(10060, 10061)
    |> set_char_var(:ep13_ryu, 5)
    |> mes("[Promotional Staff]")
    |> mes("Please bring me a Ruby.")
    |> mes("As I mentioned, this is the second request.")
    |> mes("I will wait until you bring me a stone again.")
    |> close()
  end

  defp first_stone_request(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Promotional Staff]")
      |> mes(
        "We are recruiting adventurers who are strong and curious. Try your life at something more challenging."
      )
      |> next()
      |> mes("[Promotional Staff]")
      |> mes("Hey, you're a knowledgeable person, right? Are you interested in my story?")
      |> next()
      |> select(["The Staff in Aldebaran sent me."])

    ctx
    |> mes("[Promotional Staff]")
    |> mes("Oh he did?")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("Ok, I guess that it's time for the second part of your test.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("I need you to gather some stones for me.")
    |> next()
    |> mes("[Promotional Staff]")
    |> mes("I will accept you if you bring ^FF00001 Emerald^000000.")
    |> mes("Are you ready?")
    |> next()
    |> changequest(10059, 10060)
    |> set_char_var(:ep13_ryu, 4)
    |> mes("[Promotional Staff]")
    |> mes("Just bring me ^ff00001 Emerald^000000.")
    |> mes("That isn't hard for you right?")
    |> mes("Then we can go forward.")
    |> close()
  end

  defp shared_pitch(ctx) do
    {ctx, _} = Aesir.ZoneServer.Content.Npc.Functions.PromotionalStaff.call(ctx, [])
    ctx
  end
end
