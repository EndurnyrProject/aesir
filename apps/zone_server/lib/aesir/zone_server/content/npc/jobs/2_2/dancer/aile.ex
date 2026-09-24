defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Aile do
  @moduledoc """
  Dance School receptionist who enrolls female Archers in the Dancer job quest and collects
  their tuition.

  ## Behavior

  - Turns away transcendent characters, non-Archers, and male Archers.
  - Enrolls female Archers of at least Job Level 40.
  - Assigns one of three random supply lists and checks for it together with the 10,000 Zeny
    tuition, then sends the student to Bijou for the interview.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy
    - Vicious
    - Lance
    - Skotlex

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_duncer",
        x: 43,
        y: 93,
        dir: 4,
        sprite: 724,
        name: "Aile",
        scope: :shared,
        unique_name: "Aile#da"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      upper(ctx) == 1 -> greet_transcendent(ctx)
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:archer) -> greet_non_archer(ctx)
      true -> greet_archer(ctx)
    end
  end

  defp greet_transcendent(ctx) do
    ctx
    |> mes("[Aile]")
    |> mes("One two three four,")
    |> mes("Two two three four,")
    |> mes("three four, three four,")
    |> mes("one two three four.")
    |> mes("Um?")
    |> next()
    |> mes("[Aile]")
    |> mes("I'm sorry, but you're interrupting my practice by looking at me funny.")
    |> next()
    |> mes("[Aile]")
    |> mes(".......")
    |> mes(".....Hey, haven't I seen you before?")
    |> next()
    |> mes("[Aile]")
    |> mes("Err...")
    |> mes("That's weird, I can't remember where I've seen you.")
    |> close_dialog()
  end

  defp greet_non_archer(ctx) do
    base_job_id = Rathena.job_id(base_job(ctx))

    cond do
      base_job_id == Rathena.job_id(:bard) ->
        ctx
        |> cutin("job_dancer_eir01", 2)
        |> mes("[Aile]")
        |> mes("Welcome~!")
        |> mes("Let me know")
        |> mes(
          "if you have any new songs. We can always use some new music to complement our performances."
        )
        |> close_dialog()

      base_job_id == Rathena.job_id(:dancer) ->
        ctx
        |> cutin("", 2)
        |> mes("[Aile]")
        |> mes("Welcome~!")
        |> mes("How are you")
        |> mes("these days?")
        |> mes("Do many people enjoy")
        |> mes("your performances?")
        |> close_dialog()

      true ->
        ctx
        |> cutin("job_dancer_eir03", 2)
        |> mes("[Aile]")
        |> mes("Welco--Mmm?")
        |> mes(
          "Hey, only authorized personnel can come here. Not just anyone can enter the Dance School."
        )
        |> next()
        |> mes("[Aile]")
        |> mes("If you want to watch, why don't you go to the Dance Stage in town?")
        |> close_dialog()
    end
  end

  defp greet_archer(ctx) do
    dance_q = get_char_var(ctx, :DANC_Q, 0)

    cond do
      dance_q == 0 and sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0) ->
        offer_application(ctx)

      sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) ->
        turn_away_male(ctx)

      dance_q == 1 ->
        assign_supplies(ctx)

      dance_q >= 2 and dance_q <= 4 ->
        collect_tuition(ctx, dance_q)

      dance_q == 5 ->
        ctx
        |> cutin("job_dancer_eir01", 2)
        |> mes("[Aile]")
        |> mes("Hmm...?")
        |> mes("Are you having")
        |> mes("trouble finding")
        |> mes("^CD6889Bijou^000000?")
        |> next()
        |> mes("[Aile]")
        |> mes(
          "You need to talk to her because she's in charge of the interviewing process. Don't worry, she should be somewhere here in the Dance School."
        )
        |> close_dialog()

      dance_q > 5 ->
        ctx
        |> cutin("job_dancer_eir01", 2)
        |> mes("[Aile]")
        |> mes("I'll be looking")
        |> mes("forward to a great")
        |> mes("performance~")
        |> close_dialog()

      true ->
        ctx
        |> cutin("job_dancer_eir03", 2)
        |> mes("[Aile]")
        |> mes("Welcom--Hm?")
        |> mes("Hey, only authorized")
        |> mes("personnel are allowed")
        |> mes("in here.")
        |> next()
        |> mes("[Aile]")
        |> mes(
          "If you want to watch, be quiet and don't disturb the performers. Everyone here is busy practicing so that they can become fine Dancers."
        )
        |> close_dialog()
    end
  end

  defp offer_application(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("job_dancer_eir01", 2)
      |> mes("[Aile]")
      |> mes("Welcome~!")
      |> mes("This is the")
      |> mes("'Comodo Dance School,'")
      |> mes(
        "where we teach various dances from different countries. We provide entertainement for travelers from all over the world."
      )
      |> next()
      |> mes("[Aile]")
      |> mes(
        "We also provide the opportunity for aspiring Dancers to become famous throughout the Rune-Midgarts Kingdom! Doesn't dancing in the spotlight sound spectacular?"
      )
      |> next()
      |> mes("[Aile]")
      |> mes(
        "I think it's fair to let you know that our school is selective. So we don't accept students who don't seem to have the talent to become Dancers."
      )
      |> next()
      |> cutin("job_dancer_eir02", 2)
      |> mes("[Aile]")
      |> mes("What do you think?")
      |> mes(
        "Do you want to sign up? You only have to write a couple of things on the application, and you can just come to the lessons once or twice and try it out."
      )
      |> next()
      |> cutin("job_dancer_eir01", 2)
      |> mes("[Aile]")
      |> mes("So what do")
      |> mes("you want to do~?")
      |> next()
      |> select(["Fill out the application.", "I'll pass."])

    cond do
      choice == 1 and job_level(ctx) > 39 ->
        enroll(ctx)

      choice == 1 ->
        ctx
        |> cutin("job_dancer_eir01", 2)
        |> mes("[Aile]")
        |> mes("Mmm...")
        |> mes("It seems that")
        |> mes(
          "you aren't quite qualified to enroll in our school yet. You need to be at least Job Level 40."
        )
        |> next()
        |> mes("[Aile]")
        |> mes("Well, I hope")
        |> mes("that you apply")
        |> mes("again when you meet")
        |> mes("the requirements.")
        |> close_dialog()

      true ->
        ctx
        |> cutin("job_dancer_eir01", 2)
        |> mes("[Aile]")
        |> mes("Aww~")
        |> mes("Just think about it.")
        |> mes("Don't forget to come back")
        |> mes("if you change your mind.")
        |> close_dialog()
    end
  end

  defp enroll(ctx) do
    ctx =
      ctx
      |> cutin("job_dancer_eir02", 2)
      |> mes("[Aile]")
      |> mes("Good choice!!")
      |> mes("Just fill out the application right there.")
      |> next()
      |> mes("...")
      |> next()
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("^3355FF*Shuffle Shuffle*^000000")
      |> next()
      |> cutin("job_dancer_eir01", 2)
      |> mes("[Aile]")
      |> mes("Your name is")

    ctx
    |> mes("#{char_name(ctx, 0)}?")
    |> mes(
      "Wow! What a pretty name! Just a moment, I have to show this to the director, so come back in a little bit, okay?"
    )
    |> close_dialog()
    |> set_char_var(:DANC_Q, 1)
    |> setquest(7000)
  end

  defp turn_away_male(ctx) do
    ctx
    |> cutin("job_dancer_eir03", 2)
    |> mes("[Aile]")
    |> mes("Welco--Mmm?")
    |> mes(
      "Hey, this place is only for authorized personnel. If you want to sing, you should go look into being a Bard."
    )
    |> next()
    |> mes("[Aile]")
    |> mes("Not all Archers")
    |> mes("can become Dancers.")
    |> mes("At least, not without some sort of sex change~")
    |> close_dialog()
  end

  defp assign_supplies(ctx) do
    ctx =
      ctx
      |> cutin("job_dancer_eir01", 2)
      |> mes("[Aile]")
      |> mes("Good.")
      |> mes(
        "Since you signed up earlier, I'll let you know some things you'll need to bring for your lessons."
      )
      |> next()
      |> mes("[Aile]")
      |> mes(
        "We're short on some supplies, but you'll be using them for yourself anyway. Just think of it as part of the tuition, so don't worry too much."
      )
      |> next()

    supply_roll = Enum.random(1..10)

    ctx =
      cond do
        supply_roll > 0 and supply_roll < 3 -> assign_shoes_supplies(ctx)
        supply_roll == 4 -> assign_boots_supplies(ctx)
        true -> assign_sandals_supplies(ctx)
      end

    ctx
    |> next()
    |> mes("[Aile]")
    |> mes(
      "Once you've gathered everything that you need, come back so that we can begin the lessons, okay?"
    )
    |> close_dialog()
  end

  defp assign_shoes_supplies(ctx) do
    ctx
    |> set_char_var(:DANC_Q, 2)
    |> changequest(7000, 7001)
    |> mes("[Aile]")
    |> mes(
      "First, there's the tuition fee of ^CD688910,000 Zeny^000000. Then, you'll about ^CD688920 Sticky Mucus^000000 for shoe polish."
    )
    |> next()
    |> mes("[Aile]")
    |> mes(
      "Then, bring ^CD68893 Jellopy^000000 and ^CD68895 Red Potions^000000 to use as ointment. And of course, you'll need a pair of ^CD6889Shoes^000000."
    )
    |> next()
    |> mes("[Aile]")
    |> mes("Once again, that's")
    |> mes("^CD688910,000 Zeny^000000,")
    |> mes("^CD688920 Sticky Mucus^000000,")
    |> mes("^CD68893 Jellopy^000000,")
    |> mes("^CD68895 Red Potions^000000 and")
    |> mes("^CD68891 Shoes^000000.")
  end

  defp assign_boots_supplies(ctx) do
    ctx
    |> set_char_var(:DANC_Q, 3)
    |> changequest(7000, 7002)
    |> mes("[Aile]")
    |> mes(
      "First, there's the tuition fee of ^CD688910,000 Zeny^000000. Then, bring ^CD68895 Earthworm Peelings^000000 for polishing the floor and, of course, a pair of ^CD6889Boots^000000."
    )
    |> next()
    |> mes("[Aile]")
    |> mes("Once again that's")
    |> mes("^CD688910,000 Zeny^000000,")
    |> mes("^CD68895 Earthworm Peelings^000000 and ")
    |> mes("^CD68891 Boots^000000.")
  end

  defp assign_sandals_supplies(ctx) do
    ctx
    |> set_char_var(:DANC_Q, 4)
    |> changequest(7000, 7003)
    |> mes("[Aile]")
    |> mes(
      "First, there's the tuition fee of ^CD688910,000 Zeny^000000. Then, bring ^CD68892 Clam Shells^000000 for your costume, ^CD68895 Yellow Potions^000000 and ^CD688920 Jellopy^000000 to treat foot injuries."
    )
    |> next()
    |> mes("[Aile]")
    |> mes(
      "You'll also need to bring ^CD688910 Black Hairs^000000 to make wigs for the performances and, of course, a pair of ^CD6889Sandals^000000. Once again, that's..."
    )
    |> next()
    |> mes("[Aile]")
    |> mes("^CD688910,000 Zeny^000000,")
    |> mes("^CD68892 Clam Shells^000000,")
    |> mes("^CD68895 Yellow Potions^000000,")
    |> mes("^CD688920 Jellopy^000000,")
    |> mes("^CD688910 Black Hairs^000000 and")
    |> mes("^CD6889Sandals^000000.")
  end

  defp collect_tuition(ctx, dance_q) do
    {items, counts} = required_supplies(dance_q)

    if has_all_supplies?(ctx, items, counts) and zeny(ctx) > 9999 do
      accept_tuition(ctx)
    else
      remind_supplies(ctx, items, counts)
    end
  end

  defp required_supplies(2), do: {[938, 909, 501, 2403], [20, 3, 5, 1]}
  defp required_supplies(3), do: {[1055, 2405], [5, 1]}
  defp required_supplies(4), do: {[965, 503, 909, 1020, 2401], [2, 5, 20, 10, 1]}
  defp required_supplies(_dance_q), do: {[], []}

  defp has_all_supplies?(_ctx, [], _counts), do: true

  defp has_all_supplies?(ctx, [item | items], [count | counts]) do
    if count_item(ctx, item) < count do
      false
    else
      has_all_supplies?(ctx, items, counts)
    end
  end

  defp accept_tuition(ctx) do
    ctx =
      ctx
      |> cutin("job_dancer_eir02", 2)
      |> mes("[Aile]")
      |> mes("Oh...!")
      |> mes("You brought")
      |> mes("everything!")
      |> mes("Alright then,")
      |> mes("let me take your")
      |> mes("tuition fee.")
      |> next()
      |> cutin("job_dancer_eir01", 2)
      |> pay_zeny(10_000)
      |> mes("[Aile]")
      |> mes(
        "Next, go to ^CD6889Bijou^000000, who is in charge of the interviewing process. She will have a couple of things she'll need to ask you."
      )
      |> set_char_var(:DANC_Q, 5)

    ctx =
      cond do
        checkquest(ctx, 7001) != -1 -> changequest(ctx, 7001, 7004)
        checkquest(ctx, 7002) != -1 -> changequest(ctx, 7002, 7004)
        true -> changequest(ctx, 7003, 7004)
      end

    close_dialog(ctx)
  end

  defp remind_supplies(ctx, items, counts) do
    ctx =
      ctx
      |> cutin("job_dancer_eir01", 2)
      |> mes("[Aile]")
      |> mes("Mmm...?")
      |> mes("You don't have")
      |> mes("everything yet?")
      |> mes("Let me remind you")
      |> mes("so you can bring")
      |> mes("what you need next time.")
      |> next()
      |> mes("[Aile]")
      |> mes("Bring...")
      |> mes("^CD688910,000 Zeny^000000,")

    dance_q = get_char_var(ctx, :DANC_Q, 0)

    separators =
      cond do
        dance_q == 2 -> [",", ",", " and", "."]
        dance_q == 3 -> [" and", "."]
        true -> [",", ",", ",", " and", "."]
      end

    separators
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {separator, index}, ctx ->
      count = Enum.at(counts, index, 0)
      item_name = Rathena.getitemname(Enum.at(items, index, 0))
      mes(ctx, "^CD6889#{count} #{item_name}^000000#{separator}")
    end)
    |> close_dialog()
  end

  defp close_dialog(ctx), do: ctx |> close() |> cutin("", 255)
end
