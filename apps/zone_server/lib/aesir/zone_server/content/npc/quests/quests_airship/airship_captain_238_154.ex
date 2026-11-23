defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.AirshipCaptain238154 do
  @moduledoc """
  Introduces Captain Tarlock and the airship flight quest.

  ## Behavior

  - Offers a letter delivery and explains the airship after the reply arrives.
  - Awards experience when the explanation is complete.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
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
        map: "airplane_01",
        x: 238,
        y: 154,
        dir: 3,
        sprite: 873,
        name: "Airship Captain",
        scope: :shared,
        unique_name: "Airship Captain#01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> cutin("fly_felrock", 2)
      |> mes("[Tarlock]")
      |> mes("I am Tarlock,")
      |> mes("captain of this")
      |> mes("Airship. Did you")
      |> mes("have a question?")
      |> next()

    ctx = set_question(ctx, get_char_var(ctx, :lght_air, 0))

    {ctx, choice} =
      select(
        ctx,
        Enum.flat_map(
          ["Y-you're a reindeer?!", get_local(ctx, :"question$", ""), "No, not really."],
          &String.split(&1, ":")
        )
      )

    result =
      case choice do
        1 -> {:ok, reindeer(ctx)}
        2 -> flight_question(mes(ctx, "[Tarlock]"), get_char_var(ctx, :lght_air, 0))
        3 -> {:ok, farewell(ctx)}
        _ -> {:stop, ctx}
      end

    case result do
      {:ok, ctx} -> ctx |> close() |> cutin("", 255)
      {:stop, ctx} -> ctx
    end
  end

  defp set_question(ctx, progress) when progress in 0..3 or progress == 7,
    do: set_local(ctx, :"question$", "How does this Airship fly?")

  defp set_question(ctx, 4),
    do: set_local(ctx, :"question$", "I handed the letter to Captain Ferlock.")

  defp set_question(ctx, 5), do: set_local(ctx, :"question$", "You finished reading the letter?")
  defp set_question(ctx, 6), do: set_local(ctx, :"question$", "Already finished reading?")
  defp set_question(ctx, _), do: ctx

  defp flight_question(ctx, 1) do
    if base_level(ctx) <= 59 do
      {:ok, too_young(ctx)}
    else
      ask_interest(ctx)
    end
  end

  defp flight_question(ctx, 4), do: {:ok, received_reply(ctx)}
  defp flight_question(ctx, 5), do: {:ok, reading_reply(ctx)}
  defp flight_question(ctx, 6), do: {:ok, explain_flight(ctx)}
  defp flight_question(ctx, 7), do: {:ok, already_explained(ctx)}
  defp flight_question(ctx, progress) when progress in [2, 3], do: {:ok, awaiting_reply(ctx)}
  defp flight_question(ctx, _), do: {:ok, introduce_secret(ctx)}

  defp reindeer(ctx) do
    ctx
    |> mes("[Tarlock]")
    |> mes("Hm? Oh, that")
    |> mes("We reindeer are a proud")
    |> mes("race who like to travel the")
    |> mes("world. But that should be")
    |> mes("obvious if you think of the")
    |> mes("reindeer working for Claus.")
    |> next()
    |> mes("[Tarlock]")
    |> mes("Well, reindeer or")
    |> mes("not, I've earned the")
    |> mes("captaincy of this ship")
    |> mes("and the loyalty of my crew.")
    |> mes("We'll do everything we can to")
    |> mes("make sure your flight is safe.")
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Tarlock]")
    |> mes("Alright, then.")
    |> mes("Thanks for flying")
    |> mes("with us, and I hope")
    |> mes("you enjoy your travels.")
  end

  defp too_young(ctx) do
    ctx
    |> mes("Mm...?")
    |> mes("Didn't you ask me that")
    |> mes("before? Well, in any case")
    |> mes("I apologize, but I'm still not")
    |> mes("allowed to tell you that secret.")
  end

  defp ask_interest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Mm...?")
      |> mes("Didn't you ask me that")
      |> mes("before? Are you just curious")
      |> mes("or did you really want to know?")
      |> next()
      |> select(["No, not really...", "Yes, I really want to know!"])

    case choice do
      1 -> {:ok, decline_interest(ctx)}
      2 -> offer_delivery(ctx)
      _ -> {:stop, ctx}
    end
  end

  defp decline_interest(ctx) do
    ctx
    |> mes("[Tarlock]")
    |> mes("Hahahaha~")
    |> mes("Maybe someday you'll")
    |> mes("figure out how this Airship")
    |> mes("is able to stay aloft and")
    |> mes("fly through the skies.")
  end

  defp offer_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tarlock]")
      |> mes("In all honestly, the")
      |> mes("secret to this Airship's")
      |> mes("flight is something that")
      |> mes("only captains are authorized")
      |> mes("to know. So I shouldn't really")
      |> mes("tell you anything about it.")
      |> next()
      |> mes("[Tarlock]")
      |> mes("But I've never been able")
      |> mes("to trust upper management")
      |> mes("so I don't have any loyalty to")
      |> mes("them. I wouldn't mind telling")
      |> mes("you that classified info if you")
      |> mes("do a little favor for me first.")
      |> next()
      |> select(["Let me think about it.", "Sure."])

    case choice do
      1 -> {:ok, defer_delivery(ctx)}
      2 -> {:ok, accept_delivery(ctx)}
      _ -> {:stop, ctx}
    end
  end

  defp defer_delivery(ctx) do
    ctx
    |> mes("[Tarlock]")
    |> mes("Alright. But don't")
    |> mes("worry, I'm not going")
    |> mes("to ask you to do anything")
    |> mes("that you can't handle. Come")
    |> mes("back after you decide, alright?")
  end

  defp accept_delivery(ctx) do
    ctx
    |> setquest(8032)
    |> set_char_var(:lght_air, 2)
    |> mes("[Tarlock]")
    |> mes("Ha-hah! I like you")
    |> mes("already! Alright, here's")
    |> mes("the deal. I have a younger")
    |> mes("brother who I rarely see since")
    |> mes("he's also an Airship Captain")
    |> mes("that's always traveling.")
    |> next()
    |> mes("[Tarlock]")
    |> mes("Would you bring this")
    |> mes("letter to my brother,")
    |> mes("Ferlock? Also, please")
    |> mes("make sure that you come")
    |> mes("back with his reply, alright?")
    |> mes("Thank you, adventurer.")
    |> next()
    |> mes("[Tarlock]")
    |> mes("Oh, and once you meet")
    |> mes("my brother, please help")
    |> mes("him out. He'll explain it")
    |> mes("once you see him.")
    |> next()
    |> mes("^3131FFYou have received")
    |> mes("Captain Tarlock's letter")
    |> mes("to deliver to his younger")
    |> mes("brother, Captain Ferlock.")
  end

  defp received_reply(ctx) do
    ctx
    |> set_char_var(:lght_air, 5)
    |> changequest(8034, 8035)
    |> mes("Oh!")
    |> mes("And he answer you? Really?!")
    |> mes("In fact, I wasn't")
    |> mes("expecting that too much...")
    |> mes("Please wait a little,")
    |> mes("I'll read his letter.")
  end

  defp reading_reply(ctx) do
    ctx
    |> set_char_var(:lght_air, 6)
    |> mes("Um... Ha ha ha~!")
    |> mes("This guy, he is a real lover!")
    |> mes("But his true inner man")
    |> mes("is limited by his duty.")
    |> mes("What do you think?")
    |> mes("Hoh hoh hoh.")
    |> next()
    |> mes("^3131ffHe continue reading")
    |> mes("the letter.^000000")
  end

  defp explain_flight(ctx) do
    {ctx, _} =
      ctx
      |> mes("Yes, I finished.")
      |> mes("Even if I understand him")
      |> mes("I've a totally different")
      |> mes("point of view. But both")
      |> mes("of us are fearless.")
      |> next()
      |> mes("[Tarlock]")
      |> mes("Oh, I almost forgot,")
      |> mes("I'll teach you what you")
      |> mes("wanted to know.")
      |> next()
      |> mes("[Tarlock]")
      |> mes("The Airship's secret to float is...")
      |> mes("The large boiler is setted on fire,")
      |> mes("That moves the pistons, gears")
      |> mes("and turbines with the steam")
      |> mes("that is generated when the water")
      |> mes("passes within the boiler.")
      |> next()
      |> mes("[Tarlock]")
      |> mes("That turns the propeller.")
      |> mes("That's all. Did you understand?")
      |> next()
      |> select(["Um? Only that? There's no more?"])

    {ctx, _} =
      ctx
      |> mes("[Tarlock]")
      |> mes("Ha ha ha!")
      |> mes("I explained it roughly to")
      |> mes("make it easier to understand")
      |> mes("by you. Still, you aren't")
      |> mes("pleased? I said it in plain")
      |> mes("english that everyone could")
      |> mes("understand.")
      |> next()
      |> mes("[Tarlock]")
      |> mes("Obviously, only with a steam")
      |> mes("is impossible to make this fly.")
      |> mes("Therefore, it uses an amplifier")
      |> mes("called ^ff0000Rune Mechanism^000000.")
      |> next()
      |> select(["Uh? What's a Rune Mechanism?"])

    ctx =
      ctx
      |> mes("[Tarlock]")
      |> mes("It's a device that uses a")
      |> mes("magic stone as power source.")
      |> mes("However, I don't know how")
      |> mes("this work...")
      |> mes("I forgot the details probably")
      |> mes("because I didn't paid much attention.")
      |> next()
      |> mes("[Tarlock]")
      |> mes("The only I remember is")
      |> mes("that the energy is amplified")
      |> mes("while it passes through the")
      |> mes("Rune that is attached to a")
      |> mes("steam engine.")
      |> next()
      |> mes("[Tarlock]")
      |> mes("In fact, all this airship")
      |> mes("floats thanks to the power")
      |> mes("given by the stone, no")
      |> mes("exaggeration.")
      |> mes("It has really a strong power.")
      |> next()
      |> specialeffect2(:mappillar)
      |> mes("[Tarlock]")
      |> mes("Did you understand?")
      |> mes("I'll rest a little.")
      |> mes("I'm tired for reading")
      |> mes("and writing those long")
      |> mes("letters.")
      |> completequest(8035)
      |> set_char_var(:lght_air, 7)

    if Rathena.truthy?(checkre(ctx, 3)) do
      getexp(ctx, 20_000, 1000)
    else
      getexp(ctx, 200_000, 10_000)
    end
  end

  defp already_explained(ctx) do
    ctx
    |> mes("Didn't I teach you before?")
    |> mes("I won't explain such a long")
    |> mes("tale again!")
  end

  defp awaiting_reply(ctx) do
    ctx
    |> mes("Hahahah! Don't worry, I'll")
    |> mes("tell you know this Airship")
    |> mes("flies once you deliver that")
    |> mes("letter to my brother, Ferlock,")
    |> mes("and bring back his reply.")
  end

  defp introduce_secret(ctx) do
    ctx
    |> mes("Hahaha! How this")
    |> mes("Airship flies? Yes, it's")
    |> mes("quite wonderful, isn't it?")
    |> mes("Although that's a secret,")
    |> mes("let me assure you that it's")
    |> mes("nothing weird or dangerous.")
    |> set_char_var(:lght_air, 1)
  end
end
