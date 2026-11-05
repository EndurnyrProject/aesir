defmodule Aesir.ZoneServer.Content.Npc.Quests.CounteragentMixture.Louitz do
  @moduledoc """
  Merchant Louitz, an Alberta merchant who recognizes the strange solutions the
  player carries and points the way to the chemist Morgenstein in Geffen.

  ## Behavior

  - Wants to know whether Morgenstein was found once the `molgenstain` step is 2.
  - While carrying Detrimindexta, Karvodailnirol or both, offers the Geffen
    scientist's story and reveals that the solutions belong to Morgenstein.
  - Learning about the solutions advances `molgenstain` to 1 and sends the player
    to Geffen; the solutions themselves are not consumed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Komurka
    - L0ne_W0lf
    - Everade
    - Lupus
    - Darkchild
    - Nexon

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta_in",
        x: 133,
        y: 55,
        dir: 3,
        sprite: 84,
        name: "Louitz",
        scope: :shared,
        unique_name: "Louitz#cm"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @detrimindexta 971
  @karvodailnirol 972

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :molgenstain, 0) == 2 do
      met_morgenstein_yet(ctx)
    else
      greet(ctx)
    end
  end

  defp met_morgenstein_yet(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Merchant Louitz]")
      |> mes("Oh, it's you again.")
      |> mes("So did you try finding")
      |> mes("that nutcase scientist")
      |> mes("who lives over in Geffen?")
      |> next()
      |> select(["Talk About Morgenstein", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Merchant Louitz]")
      |> mes("You know where he lives")
      |> mes("but didn't check it out? Hey,")
      |> mes("he may be off his rocker, but")
      |> mes("I guess most geniuses are")
      |> mes("like that. Still, I think it'd be^FFFFFFss^000000 a good idea if you see him.")
      |> next()
      |> mes("[Merchant Louitz]")
      |> mes("I mean...")
      |> mes("It's only a matter")
      |> mes("of time until a smart guy")
      |> mes("like that creates something")
      |> mes("truly miraculous, right?")
      |> close()
    else
      ctx
      |> mes("[Merchant Louitz]")
      |> mes("...Hello?")
      |> mes("Hellooo? Hey.")
      |> mes("Hey! I'm talkin'")
      |> mes("to you! Man, I hate")
      |> mes("it when you adventurers")
      |> mes("just shut up and space out...")
      |> close()
    end
  end

  defp greet(ctx) do
    ctx = ctx |> mes("[Merchant Louitz]") |> mes("Heya.") |> mes("What's up?") |> next()

    cond do
      count_item(ctx, @detrimindexta) > 0 and count_item(ctx, @karvodailnirol) > 0 ->
        solutions_menu(ctx)

      count_item(ctx, @karvodailnirol) > 0 ->
        karvodailnirol_menu(ctx)

      count_item(ctx, @detrimindexta) > 0 ->
        detrimindexta_menu(ctx)

      true ->
        talk_menu(ctx)
    end
  end

  defp solutions_menu(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Talk about the solutions.", "Cancel"])

    case choice do
      1 -> science_story(ctx)
      2 -> ask_about_solutions(ctx)
      3 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp karvodailnirol_menu(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Talk about Karvodailnirol", "Cancel"])

    case choice do
      1 -> science_story(ctx)
      2 -> ask_about_solution(ctx, "Karvodailnirol")
      3 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp detrimindexta_menu(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Talk about Detrimindexta", "Cancel"])

    case choice do
      1 -> science_story(ctx)
      2 -> ask_about_solution(ctx, "Detrimindexta")
      3 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp talk_menu(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Cancel"])

    if choice == 1, do: science_story(ctx), else: farewell(ctx)
  end

  defp science_story(ctx) do
    ctx
    |> mes("[Merchant Louitz]")
    |> mes("When I was in Geffen")
    |> mes("looking for magic items,")
    |> mes("I heard rumors of this really")
    |> mes("crazy scientist guy. So I got")
    |> mes("curious, asked around, and")
    |> mes("eventually found this guy.")
    |> next()
    |> mes("[Merchant Louitz]")
    |> mes("Boy, oh boy, this guy was")
    |> mes("screwy. He didn't even know")
    |> mes("I was there the whole time and")
    |> mes("just kept mumbling this mumbo")
    |> mes("jumbo while working on his")
    |> mes("experiments. Words like, um...")
    |> next()
    |> mes("[Merchant Louitz]")
    |> mes("Yeah, he kept mumbling")
    |> mes("words like ''Karvodailnirol''")
    |> mes("and ''Detrimindexta.'' The")
    |> mes("first time I heard it, I thought")
    |> mes("it was just crazy talk, you know?")
    |> next()
    |> mes("[Merchant Louitz]")
    |> mes("But it turns out,")
    |> mes("this Karvodailnirol")
    |> mes("and Detrimindexta actually")
    |> mes("exist. I think they're special")
    |> mes("liquids that don't work quite")
    |> mes("like any liquids we're used to.")
    |> close()
  end

  defp ask_about_solutions(ctx) do
    ctx
    |> set_char_var(:molgenstain, 1)
    |> mes("[Merchant Louitz]")
    |> mes("Hey, this is one of")
    |> mes("those solutions that")
    |> mes("scientist kept mentioning.")
    |> mes("You were able to get one")
    |> mes("of these? Huh. Now, I have")
    |> mes("no idea what to do with them... ")
    |> next()
    |> mes("[Merchant Louitz]")
    |> mes("Ah, but that crazy")
    |> mes("scientist would know.")
    |> mes("I don't remember exactly")
    |> mes("where he lives, but I know")
    |> mes("he's in Geffen and that his")
    |> mes("name is ^0000FFMorgenstein^000000.")
    |> next()
    |> morgenstein_hint()
  end

  defp ask_about_solution(ctx, item_name) do
    ctx
    |> set_char_var(:molgenstain, 1)
    |> mes("[Merchant Louitz]")
    |> mes("Oh hey, this is that")
    |> mes("#{item_name} that the")
    |> mes("old scientist was talking")
    |> mes("about, huh? Of course, only")
    |> mes("someone like that guy would")
    |> mes("know what to do with it...")
    |> next()
    |> mes("[Merchant Louitz]")
    |> mes("Hey, why don't you go")
    |> mes("and ask him about it?")
    |> mes("I don't remember exactly")
    |> mes("where he lives, but I know")
    |> mes("he's in Geffen and that his")
    |> mes("name is ^0000FFMorgenstein^000000.")
    |> next()
    |> morgenstein_hint()
  end

  defp morgenstein_hint(ctx) do
    ctx
    |> mes("[Merchant Louitz]")
    |> mes("Hmm... You better")
    |> mes("go around Geffen and")
    |> mes("around first. I know for")
    |> mes("ask around first. I know for")
    |> mes("sure that somebody knows")
    |> mes("where you can find Morgenstein.")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Merchant Louitz]")
    |> mes("Um...")
    |> mes("Good talking")
    |> mes("to you pal. Uh,")
    |> mes("see ya 'round. Take")
    |> mes("care of yourself, 'kay?")
    |> close()
  end
end
