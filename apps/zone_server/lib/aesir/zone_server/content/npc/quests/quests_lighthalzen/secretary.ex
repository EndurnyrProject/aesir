defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Secretary do
  @moduledoc """
  Hes O'Neil manages visits to the president.

  ## Behavior

  - Answers visitors and checks appointments and membership cards.
  - Accepts a file and grants access as the investigation progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_pre",
        x: 69,
        y: 20,
        dir: 4,
        sprite: 862,
        name: "Secretary",
        scope: :shared,
        unique_name: "Secretary#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_boss, 0)

    cond do
      stage < 11 ->
        visitor(ctx)

      stage < 16 ->
        member(ctx)

      stage == 16 ->
        receive_file(ctx)

      stage < 21 ->
        ctx
        |> mes("[Hes O'Neil]")
        |> mes("I'm sorry, but the")
        |> mes("president is currently")
        |> mes("outside on business.")
        |> mes("Please come back to")
        |> mes("visit him another time.")
        |> close()

      stage < 43 ->
        welcome(ctx)

      get_char_var(ctx, :hg_tre, 0) == 56 ->
        explain(ctx)

      get_char_var(ctx, :hg_tre, 0) > 56 ->
        ctx
        |> mes("[Hes O'Neil]")
        |> mes("The president said that you're welcome to visit him anytime.")
        |> close2()
        |> warp("yuno_pre", 113, 53)

      true ->
        ctx
        |> mes("[Hes O'Neil]")
        |> mes("I'm sorry...")
        |> mes("It seems that the")
        |> mes("president would like")
        |> mes("to have some privacy now.")
        |> close()
    end
  end

  defp visitor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("Good day, how")
      |> mes("may I help you?")
      |> next()
      |> select(["Oh. I'm fine, thanks.", "I want to meet the president~", "W-who are you...?"])

    case choice do
      1 ->
        building_notice(ctx)

      2 ->
        appointment(ctx)

      3 ->
        ctx
        |> mes("[Hes O'Neil]")
        |> mes("Hmm...?")
        |> mes("I'm the personal")
        |> mes("secretary to the")
        |> mes("president of the")
        |> mes("Schwarzwald Republic,")
        |> mes("if that's what you mean.")
        |> close()

      _ ->
        ctx
    end
  end

  defp member(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("Good day, how")
      |> mes("may I help you?")
      |> next()
      |> select(["Show Secret Wing Card.", "I'm here to see the president.", "Nothing."])

    case choice do
      1 -> show_card(ctx)
      2 -> appointment(ctx)
      3 -> building_notice(ctx)
      _ -> ctx
    end
  end

  defp building_notice(ctx),
    do:
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("Since this is an")
      |> mes("important government")
      |> mes("building, please keep")
      |> mes("in mind that certain areas,")
      |> mes("monitored by guards, are")
      |> mes("off limits to visitors.")
      |> close()

  defp appointment(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("President Weierstrass?")
      |> mes("Do you have an appointment")
      |> mes("to meet with him today?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        check_name(ctx)

      2 ->
        ctx
        |> mes("[Hes O'Neil]")
        |> mes("I'm so sorry, but because")
        |> mes("the president is an incredibly")
        |> mes("busy man, he can only make")
        |> mes("time to see the people who")
        |> mes("have an appointment.")
        |> close()

      _ ->
        ctx
    end
  end

  defp check_name(ctx) do
    ctx =
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("Alright, let me see.")
      |> mes("May I please have your")
      |> mes("name so that I can look")
      |> mes("it up in today's schedule?")
      |> next()

    {ctx, choice} =
      select(ctx, String.split(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ""), ":"))

    case choice do
      1 ->
        ctx = mes(ctx, "[Hes O'Neil]")

        ctx
        |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), "?"))
        |> mes("I'm sorry, but I can't find")
        |> mes("your name on the list. You")
        |> mes("can only visit the president")
        |> mes("if you have an appointment.")
        |> mes("Thank you for your cooperation.")
        |> close()

      _ ->
        ctx
    end
  end

  defp show_card(ctx) do
    cond do
      not Rathena.truthy?(count_item(ctx, 7348)) ->
        ctx
        |> mes("^3355FFWait a second...")
        |> mes("You don't seem to")
        |> mes("be carrying your")
        |> mes("''Secret Wing''")
        |> mes("Membership Card.^000000")
        |> close()

      (gettime(ctx, 3) > 10 and gettime(ctx, 3) < 15) or
          (gettime(ctx, 3) > 19 and gettime(ctx, 3) <= 23) ->
        ctx
        |> mes("^3355FFYou suavely flash")
        |> mes("your ''Secret Wing''")
        |> mes("Membership Card.^000000")
        |> next()
        |> mes("[Hes O'Neil]")
        |> mes("Oh... I see.")
        |> mes("The president has")
        |> mes("been expecting you.")
        |> mes("Please, right this way.")
        |> close2()
        |> warp("yuno_pre", 113, 53)

      true ->
        ctx
        |> mes("[Hes O'Neil]")
        |> mes("Oh... I see.")
        |> mes("I'm sorry, but you've")
        |> mes("come too early for your")
        |> mes("appointment. Would you")
        |> mes("come back to see the")
        |> mes("president later?")
        |> close()
    end
  end

  defp receive_file(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7342)) do
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("Hm? I thought the")
      |> mes("president was supposed")
      |> mes("to give you some kind of")
      |> mes("file, but perhaps I was")
      |> mes("mistaken? Let me think...")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("[Hes O'Neil]")
        |> mes("Hello, may I be")
        |> mes("of any assistance?")
        |> next()
        |> select(["I brought this."])

      case choice do
        1 ->
          ctx
          |> mes("[Hes O'Neil]")
          |> mes("Ah, the file folder")
          |> mes("I needed. I'm so sorry")
          |> mes("to trouble you. Thank")
          |> mes("you so much for your help.")
          |> delitem(7342, 1)
          |> set_char_var(:lhz_boss, 17)
          |> close()

        _ ->
          ctx
      end
    end
  end

  defp welcome(ctx) do
    ctx =
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("Oh, the president")
      |> mes("is expecting you.")
      |> mes("Please, go right")

    ctx = if sex(ctx) == 1, do: mes(ctx, "on ahead, sir."), else: mes(ctx, "on ahead, ma'am.")
    ctx |> close2() |> warp("yuno_pre", 113, 53)
  end

  defp explain(ctx) do
    ctx =
      ctx
      |> mes("[Hes O'Neil]")
      |> mes("The President has given the order that ")
      |> mes("nobody is allowed to enter this place.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("However, you will change your mind after listening to my explanation.")
      |> next()
      |> mes("[Hes O'Neil]")
      |> mes("...............")
      |> mes("Is it something very important?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("It is the most important thing.")
    |> next()
    |> mes("[Hes O'Neil]")
    |> mes("Alright then, there you go.")
    |> mes("(Whisper) I hope you will become his source of strength.")
    |> close2()
    |> warp("yuno_pre", 113, 53)
  end
end
