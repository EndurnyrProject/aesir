defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Boohae do
  @moduledoc """
  Meditating monk who questions candidates sent by Touha and assigns their endurance test.

  ## Behavior

  - Questions Acolytes about what Touha did for them and dismisses wrong answers.
  - Lets candidates who answer correctly choose the mushroom-gathering or marathon test.
  - Briefs candidates on their chosen test and reminds finishers to visit Tomoon.
  - Otherwise stays in meditation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 57,
        y: 179,
        dir: 1,
        sprite: 110,
        name: "Boohae",
        scope: :shared,
        unique_name: "Boohae#mk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      quest == 14 and Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        interview(ctx)

      quest == 15 ->
        brief_mushroom_test(ctx)

      quest == 16 ->
        brief_marathon(ctx)

      quest == 17 ->
        ctx
        |> mes("[Boohae]")
        |> mes("Now, go visit 'Tomoon'. How many times should I tell you this?")
        |> mes(
          "Now you have a lot of chance to damage your body because you're so exhausted right now."
        )
        |> mes("'Tomoon' is staying in a deepest place inside a building near this abbey.")
        |> close()

      quest > 17 and quest < 24 ->
        meditate(ctx, "...........")

      true ->
        meditate(ctx, "Hmmmm....!!")
    end
  end

  defp interview(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Boohae]")
      |> mes("...")
      |> next()
      |> mes("[Boohae]")
      |> mes("......")
      |> next()
      |> mes("[Boohae]")
      |> mes(".........")
      |> next()
      |> mes("[Boohae]")
      |> mes("............")
      |> next()
      |> select(["...excuse me...?"])

    {ctx, reason} =
      ctx
      |> mes("[Boohae]")
      |> mes("...")
      |> mes("You just interrupted my meditation, I should break your legs...")
      |> next()
      |> mes("[Boohae]")
      |> mes("........")
      |> mes("I will give you a chance to explain why you interrupted me.")
      |> next()
      |> mes("[Boohae]")
      |> mes(".....")
      |> next()
      |> mes("[Boohae]")
      |> mes("Well, start explaining... or you'll be crawling soon...")
      |> next()
      |> select(["Touha sent me.", "Sorry, nothing."])

    if reason == 2 do
      ctx
      |> mes("[Boohae]")
      |> mes("........")
      |> mes("...you must have a death wish to have interrupted me intentionally...")
      |> close()
    else
      ask_about_touha(ctx)
    end
  end

  defp ask_about_touha(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Boohae]")
      |> mes("I see...")
      |> mes("Well then, let's see....")
      |> next()
      |> mes("[Boohae]")
      |> mes("....your body seems..")
      |> mes("strengthened. Good...")
      |> next()
      |> mes("[Boohae]")
      |> mes("What did you do with Touha?")
      |> next()
      |> select([
        "Umm... well...ah..",
        "We recited a holy pledge.",
        "He diagnosed my physical status."
      ])

    case answer do
      1 ->
        dismiss_unready(ctx)

      2 ->
        ask_what_touha_did(ctx)

      3 ->
        ctx
        |> mes("[Boohae]")
        |> mes("...You interrupted me to tell me that...?")
        |> mes("Get lost before I break your legs...")
        |> close()

      _ ->
        choose_test(ctx)
    end
  end

  defp ask_what_touha_did(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Boohae]")
      |> mes("... I see...")
      |> mes("Didn't he do anything for you?")
      |> next()
      |> select([
        "Umm... well...ah..",
        "He diagnosed my physical status.",
        "He taught me about being a monk.",
        "He modified my body."
      ])

    case answer do
      1 ->
        dismiss_unready(ctx)

      2 ->
        ctx
        |> mes("[Boohae]")
        |> mes("That is unimportant to me...")
        |> mes("Stop disturbing me and go away!")
        |> close()

      3 ->
        ctx
        |> mes("[Boohae]")
        |> mes("The teachings of becoming a monk are learned after becoming one.")
        |> mes("This is not what I am looking for...")
        |> close()

      4 ->
        ctx
        |> mes("[Boohae]")
        |> mes("Very well, you seem to realize your body has something new inside.")
        |> mes("Well then, we shall move on to the next step...")
        |> next()
        |> choose_test()

      _ ->
        choose_test(ctx)
    end
  end

  defp dismiss_unready(ctx) do
    ctx
    |> mes("[Boohae]")
    |> mes("You are not ready if you")
    |> mes("cannot answer a simple question.")
    |> mes("Leave me to my prayers.")
    |> close()
  end

  defp choose_test(ctx) do
    {ctx, test} =
      ctx
      |> mes("[Boohae]")
      |> mes("Alright... well we have two tests...")
      |> mes("Choose which one you want to do...")
      |> next()
      |> select(["Gathering mushrooms", "Marathon"])

    if test == 1 do
      ctx
      |> set_char_var(:MONK_Q, 15)
      |> changequest(3026, 3027)
      |> mes("[Boohae]")
      |> mes("Hmm....gathering mushrooms. So you want to test your tolerance huh?")
      |> mes("Go prepare and come back later when you're ready.")
      |> close()
    else
      ctx
      |> set_char_var(:MONK_Q, 16)
      |> changequest(3026, 3028)
      |> mes("[Boohae]")
      |> mes(
        "Good choice. Forcing your physical limits to their boundaries and grants a higher amount of self control."
      )
      |> mes("Go prepare and come back later when you're ready.")
      |> close()
    end
  end

  defp brief_mushroom_test(ctx) do
    ctx
    |> mes("[Boohae]")
    |> mes("So, are you ready? You won't need anything but a great deal of determination.")
    |> next()
    |> mes("[Boohae]")
    |> mes("The gathering mushroom test is intended,")
    |> mes("to test your patience.")
    |> next()
    |> mes("[Boohae]")
    |> mes("Go inside the building near this abbey.")
    |> next()
    |> mes("[Boohae]")
    |> mes("Other monk candidates will be with you for the same test,")
    |> next()
    |> mes("[Boohae]")
    |> mes("The more people that are there, the less mushrooms they'll find.")
    |> mes("So I hope you will understand that they are testing their patience, just like you.")
    |> close()
  end

  defp brief_marathon(ctx) do
    ctx
    |> mes("[Boohae]")
    |> mes("Welcome back, did you prepare? You won't need anything except strong legs.")
    |> next()
    |> mes("[Boohae]")
    |> mes("The marathon is intended,")
    |> mes("to test your self-control ability.")
    |> next()
    |> mes("[Boohae]")
    |> mes("Go inside the building near this abbey.")
    |> next()
    |> mes("[Boohae]")
    |> mes("All you have to do is run around the building as many times as you're required.")
    |> mes("Well... get going.")
    |> close()
  end

  defp meditate(ctx, murmur) do
    ctx
    |> mes("[Boohae]")
    |> mes(murmur)
    |> next()
    |> mes("-He seems to be in meditation.-")
    |> close()
  end
end
