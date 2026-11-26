defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ColonelVito15974 do
  @moduledoc """
  Trains a disguised recruit at the Thor Volcano camp.

  ## Behavior

  - Guides the recruit through verbal training, inspection duty, and physical training.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thor_camp",
        x: 159,
        y: 74,
        dir: 3,
        sprite: 946,
        name: "Colonel Vito",
        scope: :shared,
        unique_name: "Colonel Vito#3"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :aru_vol, 0) do
      14 ->
        ctx =
          ctx
          |> mes("[Colonel Vito]")
          |> mes("I am Colonel Vito,")
          |> mes("and I'm in charge of")
          |> mes("the Arunafeltz camp")
          |> mes("here in Thor Volcano.")
          |> mes("What's your name, soldier?")
          |> next()

        ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

        ctx
        |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ", sir."))
        |> next()
        |> mes("[Colonel Vito]")
        |> mes("Hmpf! That's a weakling's")
        |> mes("name! I can tell that your")
        |> mes("mind and body are too weak!")
        |> mes("That won't do. How will you")
        |> mes("be worthy of serving the")
        |> mes("beautiful, graceful Freya?")
        |> next()
        |> mes("[Colonel Vito]")
        |> mes("You need more training.")
        |> mes("Take a break first, and")
        |> mes("prepare yourself. We will")
        |> mes("begin as soon as you're ready.")
        |> set_char_var(:aru_vol, 15)
        |> close()

      15 ->
        ctx =
          ctx
          |> mes("[Colonel Vito]")
          |> mes("First, we need to take")
          |> mes("care of that weak mind")
          |> mes("of yours. This first")
          |> mes("training exercise will")
          |> mes("be verbal based.")
          |> next()
          |> ask_devotion()
          |> mes("[Colonel Vito]")
          |> mes("Right! Freya is not only")
          |> mes("a goddess of love, but she's")
          |> mes("also a goddess of war.")
          |> mes("We are on a sacred mission")
          |> mes("to recover the pieces of")
          |> mes("Ymir's Heart for her sake.")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("Freya was greatly wounded")
          |> mes("in the war among gods,")
          |> mes("humans, and demons.")
          |> mes("Odin, the leader of the")
          |> mes("gods, tried to help her, but")
          |> mes("even his power wasn't enough.")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("Odin did advise her to")
          |> mes("obtain Ymir's Heart, as")
          |> mes("it would fully recover her")
          |> mes("powers. That is why we are")
          |> mes("preparing for war: we must")
          |> mes("obtain Ymir's Heart for Freya!")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("DO YOU UNDERSTAND?!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Yes, sir!")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("Now, there's a country")
          |> mes("called the Rune-Midgarts")
          |> mes("Kingdom that's full of fools.")
          |> mes("Their ancestors branded us")
          |> mes("as heretics and drove us")
          |> mes("to this deserted land.")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("We cannot forgive how they")
          |> mes("denied us our freedom to")
          |> mes("worship Freya. Our people")
          |> mes("will have revenge on them.")
          |> mes("Mark my word, soldier.")
          |> mes("Now, repeat after me.")
          |> next()
          |> mes("[Colonel Vito]")

        ctx =
          ctx |> mes(Rathena.concat(Rathena.concat("I, ", char_name(ctx, 0)), ",")) |> next()

        ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

        ctx
        |> mes(Rathena.concat(Rathena.concat("I, ", char_name(ctx, 0)), ","))
        |> next()
        |> pledge_devotion()
        |> pledge_honor()
        |> pledge_mercy()
        |> pledge_life()
        |> pledge_victory()
        |> mes("[Colonel Vito]")
        |> mes("Good. Now you know the")
        |> mes("kind of attitude that you")
        |> mes("must have as a holy warrior")
        |> mes("in Freya's service. That")
        |> mes("is all for the first exercise,")
        |> mes("but there's one more left.")
        |> changequest(2123, 2124)
        |> set_char_var(:aru_vol, 16)
        |> close()

      16 ->
        ctx
        |> mes("[Colonel Vito]")
        |> mes("Before we actually do")
        |> mes("the 2nd training exercise,")
        |> mes("I have a duty to assign to")
        |> mes("you. Find the huge pipe zone")
        |> mes("to the north of this building")
        |> mes("and find any broken machines.")
        |> set_char_var(:aru_vol, 17)
        |> close()

      17 ->
        ctx
        |> mes("[Colonel Vito]")
        |> mes("Inspect the machines")
        |> mes("in the pipe zone to the")
        |> mes("north of this building.")
        |> mes("Don't dawdle: move out!")
        |> close()

      18 ->
        ctx =
          ctx
          |> mes("[Colonel Vito]")
          |> mes("Good work. Remember")
          |> mes("that your first priority is to")
          |> mes("check the control panel.")
          |> mes("It needs to be regularly")
          |> mes("inspected since it controls")
          |> mes("the camp's energy resources.")
          |> next()

        {ctx, choice} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Yes, sir!")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("Now it's time for the")
          |> mes("second training exercise")
          |> mes("which will strengthen your")
          |> mes("body. See the dummy in")
          |> mes("front of you? Practice by")
          |> mes("chopping it 10 times. Go!")
          |> changequest(2125, 2126)
          |> set_char_var(:aru_vol, 19)
          |> next()
          |> select(["Yes, sir!", "What do you mean by chop?"])

        if choice == 1 do
          ctx
          |> mes("[Colonel Vito]")
          |> mes("Focus your energy in")
          |> mes("your yell when you strike!")
          |> mes("Chop! 10 Times! Do it!")
          |> close()
        else
          ctx
          |> mes("[Colonel Vito]")
          |> mes("Chop...? It's a hand chop.")
          |> mes("You strike the enemy with")
          |> mes("the bottom of your hand")
          |> mes("like a knife blade. How")
          |> mes("did you join the army")
          |> mes("without knowing that?")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("Focus your energy in")
          |> mes("your yell when you strike!")
          |> mes("Chop! 10 Times! Do it!")
          |> close()
        end

      20 ->
        ctx =
          ctx
          |> mes("[Colonel Vito]")
          |> mes("The more you train,")
          |> mes("the stronger you become.")
          |> mes("As you grow stronger, so")
          |> mes("does Freya's holy troops.")
          |> mes("Train everyday, and don't")
          |> mes("you ever slack off!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Yes, sir!")
          |> next()
          |> mes("[Colonel Vito]")
          |> mes("That is all for your")
          |> mes("training. If you have")
          |> mes("any questions about camp")
          |> mes("life, go ask Sahedi right")
          |> mes("outside this building.")
          |> mes("You are dismissed.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("(^333333Well... I think")
        |> mes("I will go back to")
        |> mes("Sahedi. Hopefully,")
        |> mes("he'll think of me as")
        |> mes("a geological researcher")
        |> mes("instead of as a soldier.^000000)")
        |> changequest(2126, 2127)
        |> set_char_var(:aru_vol, 21)
        |> close()

      _ ->
        ctx
        |> mes("[Colonel Vito]")
        |> mes("We must be ever")
        |> mes("vigilant in our training.")
        |> mes("You can never know when")
        |> mes("Freya will call on us to fight!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_devotion(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Colonel Vito]")
      |> mes("Question one!")
      |> mes("Who do we fight for?")
      |> mes("Who do we live for?")
      |> next()
      |> select(["Odin", "Freya", "Thor"])

    if choice == 2 do
      ctx
    else
      ctx
      |> mes("[Colonel Vito]")
      |> mes("You idiot!")
      |> percent_heal(hp: -10, sp: 0)
      |> specialeffect2(:hit2)
      |> next()
      |> ask_devotion()
    end
  end

  defp pledge_devotion(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Colonel Vito]")
      |> mes("^FF0000as a devoted servant")
      |> mes("of Goddess Freya")
      |> next()
      |> input(:string)

    ctx =
      ctx
      |> set_local(:"input$", answer)
      |> set_local(:"answer$", "as a devoted servant of Goddess Freya")

    if get_local(ctx, :"input$", "") == get_local(ctx, :"answer$", "") do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("as a devoted servant")
      |> mes("of Goddess Freya, the")
      |> mes("patron saint of the")
      |> mes("great Arunafeltz,^000000")
      |> next()
    else
      ctx
      |> mes("[Colonel Vito]")
      |> mes("Wrong! Try again!")
      |> next()
      |> pledge_devotion()
    end
  end

  defp pledge_honor(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Colonel Vito]")
      |> mes("^FF0000I pledge my honor to")
      |> mes("overthrow our mortal enemy")
      |> next()
      |> input(:string)

    ctx =
      ctx
      |> set_local(:"input$", answer)
      |> set_local(:"answer$", "I pledge my honor to overthrow our mortal enemy")

    if get_local(ctx, :"input$", "") == get_local(ctx, :"answer$", "") do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I pledge my honor to")
      |> mes("overthrow our mortal enemy,")
      |> mes("the Rune-Midgarts Kingdom.")
      |> next()
    else
      ctx
      |> mes("[Colonel Vito]")
      |> mes("Wrong! Try again!")
      |> next()
      |> pledge_honor()
    end
  end

  defp pledge_mercy(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Colonel Vito]")
      |> mes("^FF0000I will show no mercy^000000")
      |> next()
      |> input(:string)

    ctx = ctx |> set_local(:"input$", answer) |> set_local(:"answer$", "I will show no mercy")

    if get_local(ctx, :"input$", "") == get_local(ctx, :"answer$", "") do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I will show no mercy.")
      |> mes("Nothing will stay my hand.^000000")
      |> next()
    else
      ctx
      |> mes("[Colonel Vito]")
      |> mes("Wrong! Try again!")
      |> next()
      |> pledge_mercy()
    end
  end

  defp pledge_life(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Colonel Vito]")
      |> mes("^FF0000I shall devote")
      |> mes("my entire life^000000")
      |> next()
      |> input(:string)

    ctx =
      ctx
      |> set_local(:"input$", answer)
      |> set_local(:"answer$", "I shall devote my entire life")

    if get_local(ctx, :"input$", "") == get_local(ctx, :"answer$", "") do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I shall devote my")
      |> mes("entire life to the")
      |> mes("full recovery of")
      |> mes("Goddess Freya.^000000")
      |> next()
    else
      ctx
      |> mes("[Colonel Vito]")
      |> mes("Wrong! Try again!")
      |> next()
      |> pledge_life()
    end
  end

  defp pledge_victory(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Colonel Vito]")
      |> mes("^FF0000Down with the")
      |> mes("Rune-Midgarts Kingdom!^000000")
      |> next()
      |> input(:string)

    ctx =
      ctx
      |> set_local(:"input$", answer)
      |> set_local(:"answer$", "Down with the Rune-Midgarts Kingdom!")

    if get_local(ctx, :"input$", "") == get_local(ctx, :"answer$", "") do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Down with the")
      |> mes("Rune-Midgarts Kingdom!^000000")
      |> next()
    else
      ctx
      |> mes("[Colonel Vito]")
      |> mes("Wrong! Try again!")
      |> next()
      |> pledge_victory()
    end
  end
end
