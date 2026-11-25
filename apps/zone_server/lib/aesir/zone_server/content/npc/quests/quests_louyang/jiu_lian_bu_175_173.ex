defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.JiuLianBu175173 do
  @moduledoc """
  Welcomes visitors to Jiu Lian Bu's secluded resting place.

  ## Behavior

  - Helps the player release stress by shouting across the map.
  - Lets returning visitors shout again or leave the area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_fild01",
        x: 175,
        y: 173,
        dir: 3,
        sprite: 819,
        name: "Jiu Lian Bu",
        scope: :shared,
        unique_name: "Jiu Lian Bu#1-2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = emotion(ctx, :smile)

    case get_char_var(ctx, :ch_tre, 0) do
      4 -> first_visit(ctx)
      5 -> revisit(ctx)
      _ -> dismiss(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp first_visit(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("So...")
    |> mes("Whaddya think?")
    |> mes("Prettiest place")
    |> mes("in Luoyang, isn't it?")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("Whenever I'm depressed")
    |> mes(
      "or need to relax, I just sit here in enjoy the breeze. It helps me forget all my worries."
    )
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "Heh heh, the best part is, this place is far away from my older sister. Man, that woman can nag, nag, nag, all day long."
    )
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "Why don't you sit down and close your eyes, and feel that soothing wind. It's pretty refreshing..."
    )
    |> next()
    |> emotion(:scratch)
    |> mes("[Jiu Lian Bu]")
    |> mes("Also...")
    |> mes("I'm a little")
    |> mes("embarrassed to")
    |> mes("say this but...")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "I'm the kind of guy who speaks his mind. If there's something you just wanna say, but can't, it's kind of like poison in your mind."
    )
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "You know what I'm talking about, right? If you bottle something up inside of you, it just causes you anxiety you don't need."
    )
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("So...")
    |> mes("This is what you do.")
    |> mes("Clench your fist, take")
    |> mes("a deep breath.")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("And just yell")
    |> mes("whatever you want!")
    |> mes("If you don't know")
    |> mes("the words, just")
    |> mes("screaming will do.")
    |> mes("Let everything out!")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("Ready~!")
    |> mes("Say it out loud!")
    |> next()
    |> shout()
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("So, how do you feel?")
    |> mes("Don't you feel better now? Hahaha~")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("So from now on, whenever you")
    |> mes(
      "wanna relieve yourself of stress, come see me and we'll come back to this place. Call it my way of saying thanks."
    )
    |> set_char_var(:ch_tre, 5)
    |> close()
  end

  defp revisit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jiu Lian Bu]")
      |> mes("So...")
      |> mes("Whaddya wanna do?")
      |> next()
      |> select(["Shout.", "Leave."])

    if choice == 1 do
      ctx
      |> mes("[Jiu Lian Bu]")
      |> mes("Alright~!")
      |> mes("Say it out loud!")
      |> next()
      |> shout()
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("So, how do you feel? Don't you feel better now?")
      |> close()
    else
      ctx
      |> mes("[Jiu Lian Bu]")
      |> mes("Ahhh...")
      |> mes("Alright, let's")
      |> mes("get a groove on.")
      |> close2()
      |> warp("lou_fild01", 200, 174)
    end
  end

  defp shout(ctx) do
    {ctx, input} = input(ctx, :string)
    ctx = set_local(ctx, :"input$", input)
    ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    ctx = mes(ctx, get_local(ctx, :"input$", ""))

    mapannounce(
      ctx,
      "lou_fild01",
      Rathena.concat(
        Rathena.concat(Rathena.concat("'", char_name(ctx, 0)), "' shouts : "),
        get_local(ctx, :"input$", "")
      ),
      1,
      "0x9CFF00"
    )
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Hey, pal~! This is my turf! Whaddya think you're doin' here?!")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("Now...")
    |> mes("Get the hell")
    |> mes("outta here.")
    |> close2()
    |> warp("lou_fild01", 200, 174)
  end
end
