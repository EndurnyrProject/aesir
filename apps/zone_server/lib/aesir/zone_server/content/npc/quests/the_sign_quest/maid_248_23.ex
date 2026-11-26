defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Maid24823 do
  @moduledoc """
  Elle talks to visitors about her life and Master Metz.

  ## Behavior

  - Her conversations change with progress in The Sign quest.
  - She accepts a White Potion when she is tired.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Changed the original `sign_q < 14` check to `sign_q < 12` to make stage 12 reachable.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 248,
        y: 23,
        dir: 0,
        sprite: 111,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#sign2"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Elle]")
    sign_q = get_char_var(ctx, :sign_q, 0)

    cond do
      sign_q < 3 ->
        ctx
        |> mes("Wh-what are you")
        |> mes("doing in Master Metz's")
        |> mes("room? Please leave")
        |> mes("immediately!")
        |> close()

      sign_q < 12 ->
        early_conversation(ctx)

      sign_q < 13 ->
        ctx
        |> mes("I'm not so busy")
        |> mes("nowadays, but I was")
        |> mes("working hard for a while")
        |> mes("so my body aches. Oh, what")
        |> mes("am I saying? Please ignore")
        |> mes("that--! Ho ho ho~")
        |> emotion(:profusely_sweat)
        |> close()

      sign_q < 15 ->
        ctx
        |> mes("Guys never understand")
        |> mes("what a girl really wants!")
        |> mes("They're always too afraid")
        |> mes("of showing their interest~")
        |> next()
        |> mes("[Elle]")
        |> mes("Well, even when they")
        |> mes("do ask me on dates, I never")
        |> mes("accept their proposals that")
        |> mes("easily. Hmph, there's not")
        |> mes("too many boys I like out")
        |> mes("there, anyway.")
        |> emotion(:hng)
        |> close()

      sign_q < 20 ->
        tired_conversation(ctx)

      sign_q < 25 ->
        ctx
        |> mes("Jesqurienne?")
        |> mes("Well, she's beautiful")
        |> mes("and talented. She's actually")
        |> mes("really great. That's why...")
        |> next()
        |> mes("[Elle]")
        |> mes("I consider her")
        |> mes("my rival! She might")
        |> mes("be smarter than me,")
        |> mes("but maybe I can become")
        |> mes("more beautiful than her...")
        |> emotion(:think)
        |> close()

      sign_q < 35 ->
        ctx
        |> mes("Have you been")
        |> mes("in Comodo before?")
        |> mes("It's such a beautiful")
        |> mes("place with so many")
        |> mes("things to do!")
        |> next()
        |> mes("[Elle]")
        |> mes("I like gambling in")
        |> mes("Comodo, but I think")
        |> mes("it's a little addictive.")
        |> mes("I've even seen people")
        |> mes("who seem to live for it...")
        |> close()

      sign_q < 54 ->
        ctx
        |> mes("I remember that")
        |> mes("there was a lady")
        |> mes("working for Master")
        |> mes("Bakerlan named Seylin.")
        |> mes("I hear she's from some")
        |> mes("distant country...")
        |> next()
        |> mes("[Elle]")
        |> mes("I've seen her")
        |> mes("once and I think")
        |> mes("she has a unique")
        |> mes("style of beauty. Well,")
        |> mes("different than mine or")
        |> mes("Jesquienne's anyway...")
        |> close()

      sign_q == 54 ->
        boyfriend_conversation(ctx)

      sign_q == 97 ->
        ctx
        |> mes("Ah~ Hello!")
        |> mes("Nice to see")
        |> mes("you again~")
        |> next()
        |> mes("[Elle]")
        |> mes(
          "Er, I'm sorry, but I heard that something bad happened to you. But don't worry, maybe you'll have better luck next time~"
        )
        |> close()

      true ->
        ctx
        |> mes("^333333*Sigh...*^000000")
        |> mes("Lately, there've")
        |> mes("been too many guests")
        |> mes("visiting Master Metz.")
        |> mes("Why can't they leave their")
        |> mes("dirt outside of the manor?")
        |> emotion(:hng)
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp early_conversation(ctx) do
    ctx =
      ctx
      |> mes("Oh...?")
      |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), "?"))
      |> mes("Is there anything that")
      |> mes("I can help you with?")
      |> next()

    if sex(ctx) == 1 do
      {ctx, choice} = select(ctx, ["You wanna have coffee sometime?", "Tell me about Metz."])
      early_choice(ctx, choice, :male)
    else
      {ctx, choice} = select(ctx, ["You have nice skin, Miss Elle.", "Tell me about Metz."])
      early_choice(ctx, choice, :female)
    end
  end

  defp early_choice(ctx, 1, :male) do
    ctx
    |> mes("[Elle]")
    |> mes("...?")
    |> mes("*Blush~*")
    |> mes("Oh~ A-are you")
    |> mes("asking me out")
    |> mes("on a date?")
    |> next()
    |> mes("[Elle]")
    |> mes("Weeeell~")
    |> mes("Do I have the time")
    |> mes("to go out with you or")
    |> mes("not? Hm, maybe if")
    |> mes("you're really nice")
    |> mes(Rathena.concat(Rathena.concat("to me, , ", char_name(ctx, 0)), "."))
    |> close()
  end

  defp early_choice(ctx, 1, :female) do
    ctx
    |> mes("[Elle]")
    |> mes("Eh...?")
    |> mes("Why, thank you!")
    |> mes("Maybe it's because")
    |> mes("I don't go out too")
    |> mes("often. You have nice")
    |> mes(Rathena.concat(Rathena.concat("I don't go out too, ", char_name(ctx, 0)), "~"))
    |> close()
  end

  defp early_choice(ctx, 2, sex) do
    ctx =
      ctx
      |> mes("[Elle]")
      |> mes("Umm....")
      |> mes("I don't know")
      |> mes("what to say?")
      |> next()
      |> mes("[Elle]")
      |> mes("He's my employer and")
      |> mes("I have an opinion of him,")
      |> mes("but if I told you, it might")
      |> mes("look unprofessional. But")
      |> mes("if you have time later, I just")

    if sex == :male do
      ctx |> mes("might tell you. Ho ho~") |> close()
    else
      ctx |> mes("might tell you.") |> close()
    end
  end

  defp early_choice(ctx, _, _), do: ctx

  defp tired_conversation(ctx) do
    ctx =
      ctx
      |> mes("^333333*Phew....*^000000")
      |> mes("I'm so tired, even")
      |> mes("though I didn't work")
      |> mes("that much today. Some")
      |> mes("days I feel exhausted")
      |> mes("for no reason at all...")
      |> next()
      |> mes("[Elle]")
      |> mes("I should take")
      |> mes("the day off and")
      |> mes("rest. If I had some")
      |> mes("refreshment, that")
      |> mes("would be perfect...")
      |> close2()

    if count_item(ctx, 504) > 0 do
      {ctx, _} = select(ctx, ["Why don't you take this?"])

      ctx
      |> mes("[Elle]")
      |> mes("Oh, you didn't")
      |> mes("need to do this,")
      |> mes("but that you soooo")
      |> mes("much! Ahhhhhhh~")
      |> delitem(504, 1)
      |> close2()
      |> emotion(:chupchup)
    else
      ctx
    end
  end

  defp boyfriend_conversation(ctx) do
    {ctx, choice} =
      ctx
      |> emotion(:delight)
      |> mes("La la la~~")
      |> mes("Oh, hello.")
      |> mes("Long time no see.")
      |> mes("La la la~~")
      |> next()
      |> select(["What's up?", "What happened?"])

    case choice do
      1 ->
        ctx
        |> mes("[Elle]")
        |> mes("Oh...?")
        |> mes("Oops...!")
        |> mes("Do I really")
        |> mes("look that excited?")
        |> next()
        |> mes("[Elle]")
        |> mes("I just started")
        |> mes("going out with someone!")
        |> mes("He's a tall handsome boy")
        |> mes("and I'm so in love with")
        |> mes("him and he's so....")
        |> next()
        |> mes("^3355FFElle continued")
        |> mes("talking about how")
        |> mes("much she loves her")
        |> mes("new boyfriend, even")
        |> mes("after you leave the room.^000000")
        |> close()

      2 ->
        ctx
        |> mes("[Elle]")
        |> mes("Umm....")
        |> mes("Yes, something")
        |> mes("very good happened")
        |> mes("to me. Ho ho ho ho!")
        |> mes("But it's a secret~")
        |> close()

      _ ->
        ctx
    end
  end
end
