defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Sage.StaffOfTheAcademy do
  @moduledoc """
  Metheus Sylphe, the Sage academy staff member who handles enrollment applications.

  ## Behavior

  - Turns away transcendent characters and greets non-Mages with class-specific small talk.
  - Explains enrollment to Mages and accepts applications from Mages of job level 40 or
    higher with no unspent skill points.
  - Waives the fee at job level 50; otherwise accepts 70,000 zeny or an Old Magicbook and
    Necklace of Wisdom.
  - Offers poorer candidates a random item set plus 30,000 zeny as a discounted fee.
  - Registers accepted candidates for the written entrance test.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Unknown Translator
    - Darkchild
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in03",
        x: 154,
        y: 35,
        dir: 4,
        sprite: 742,
        name: "Staff of the Academy",
        scope: :shared,
        unique_name: "Staff of the Academy#a"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Metheus Sylphe]")

    cond do
      upper(ctx) == 1 ->
        ctx
        |> mes("Welcome to the")
        |> mes("Schweicherbil Magic")
        |> mes("Academy. W-wait a second...")
        |> mes("Do I know you from somewhere?")
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes("We've met before, haven't")
        |> mes("we? Oh gosh, I must sound")
        |> mes("pretty crazy. I'm sorry, I guess it's because I haven't been")
        |> mes("sleeping too well? Oh well,")
        |> mes("have a good day, adventurer~")
        |> close()

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:mage) ->
        ctx |> greet_non_mage() |> close()

      true ->
        talk_to_candidate(ctx, get_char_var(ctx, :SAGE_Q, 0))
    end
  end

  defp greet_non_mage(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:sage) ->
        ctx
        |> mes("Oh nice to meet you again, long time no see.")
        |> mes("So how's it going with the studying?")
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes("It's okay to study books and magic scrolls all day, ")
        |> mes(
          "but you must go outside and fight with monsters as much as you can in order to be a well experienced Sage."
        )
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes("If you know any Sage candidates, please give them some advice...")
        |> mes("Also, please give my regards to your colleagues as well.")

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("Welcome to the Schweicherbil Magic Academy.")
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes(
          "This place is specialized in Sage class training. Mostly, what we do is study about monsters and magic spells."
        )
        |> mes("We always welcome new students.")
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes(
          "People who are at job jevel 40 as Mage class are qualified to apply for enrollment."
        )
        |> mes("By passing selected courses, we will then approve them as Sages.")
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes("If you're interested in the Sage class, please come again.")
        |> mes("And have a good day.")

      true ->
        ctx
        |> mes("Welcome to the Schweicherbil Magic Academy.")
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes(
          "This place is specialized in Sage class training. What we do is study about monsters and magic spells."
        )
        |> mes(
          "People who are at job jevel 40 as Mage class are qualified to apply for enrollment."
        )
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes("If you have any Mage friends, please let them know about this academy.")
        |> mes("Have a good day.")
    end
  end

  defp talk_to_candidate(ctx, 0) do
    {ctx, choice} =
      ctx
      |> mes("Welcome to the Schweicherbil Magic Academy.")
      |> mes("Oh, You're a Mage. How may I assist you?")
      |> next()
      |> select([
        "Let me know about the Sage job change.",
        "I want to enroll in the school.",
        "Nothing."
      ])

    case choice do
      1 -> explain_graduation(ctx)
      2 -> offer_enrollment(ctx)
      3 -> say_goodbye(ctx)
      _ -> ctx
    end
  end

  defp talk_to_candidate(ctx, quest) when quest >= 1 and quest <= 3 do
    ctx = ctx |> mes("Welcome, once again.") |> next()

    cond do
      count_item(ctx, 1006) > 0 and count_item(ctx, 1007) > 0 ->
        ctx
        |> delitem(1006, 1)
        |> delitem(1007, 1)
        |> mes("[Metheus Sylphe]")
        |> mes("Well done. Let me proceed with your application request.")
        |> set_char_var(:SAGE_Q, 4)
        |> next()
        |> complete_application(0)

      zeny(ctx) > 69_999 ->
        ctx
        |> pay_zeny(70_000)
        |> mes("[Metheus Sylphe]")
        |> mes("Well done. Let me proceed with your application request.")
        |> set_char_var(:SAGE_Q, 4)
        |> next()
        |> complete_application(0)

      true ->
        collect_discounted_fee(ctx, discount_requirements(get_char_var(ctx, :SAGE_Q, 0)))
    end
  end

  defp talk_to_candidate(ctx, 4) do
    ctx
    |> mes("Huh? What are you doing here? You're supposed to be taking the entrance test by now.")
    |> mes("Please visit Professor Claytos in the left room.")
    |> close()
  end

  defp talk_to_candidate(ctx, 15) do
    ctx
    |> mes("Oh, are you done with the dissertation?")
    |> mes("Sure, you can submit it to Dean Kayron.")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("So long as you make the effort, you should achieve good results.")
    |> mes("Good luck.")
    |> close()
  end

  defp talk_to_candidate(ctx, _quest) do
    ctx
    |> mes("Oh sorry, this is a rather inconvenient time to converse.")
    |> mes("Please come back later. I apologize for troubling you.")
    |> close()
  end

  defp explain_graduation(ctx) do
    ctx
    |> mes("[Metheus Sylphe]")
    |> mes("I see. Do you wish to become a Sage?")
    |> mes("Unfortunately, we are not in charge of changing your job to the Sage class.")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("After you enter this academy and pass certain courses...")
    |> mes("you will receive official approval to conduct studies as a Sage.")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes(
      "For this reason, we do not speak of this proccess as a job change, but as graduation."
    )
    |> mes(
      "Anyway, if you enter your application for this academy, I will inform you about the registration fee and will let you take the test."
    )
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes(
      "For your information, if you bring ^3355FFOld Magicbook^000000 and ^3355FFNecklace of Wisdom^000000, "
    )
    |> mes("you don't have to pay for the Registration Fee to enroll in the school.")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("After you register, you will be able to take the entrance test.")
    |> mes("If you pass the test, you will write a thesis for a given subject.")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("The Dean of the academy will decide whether or not you are qualified.")
    |> mes(
      "If you're granted admission, you will be able to join in study and research activities as a Sage."
    )
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("You're always welcome to join us.")
    |> mes("Have a good day.")
    |> close()
  end

  defp say_goodbye(ctx) do
    ctx
    |> mes("[Metheus Sylphe]")
    |> mes("I see, take your time. You can also take a look around.")
    |> mes("Goodbye, and have a good day.")
    |> close()
  end

  defp take_your_time(ctx) do
    ctx
    |> mes("[Metheus Sylphe]")
    |> mes("Ah yes, take your time...")
    |> mes("Goodbye, and have a good day.")
    |> close()
  end

  defp offer_enrollment(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes(
        "I see, you want to join the academy. Once again, welcome to the Schweicherbil Magic Academy."
      )
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes(
        "People who have already met the basic requirement by reaching at Mage job level 40 are qualified for enrollment."
      )
      |> mes("A small registration fee will also be required.")
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("The registration fee is 70,000 zeny.")
      |> mes(
        "However, if you bring ^3355FFOld Magicbook^000000 and ^3355FFNecklace of Wisdom^000000, you will be exempt from this fee."
      )
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("So, do you wish to apply immediately?")
      |> next()
      |> select(["Yes, I do.", "The fee is much too expensive.", "I will come back later."])

    case choice do
      1 -> apply_for_enrollment(ctx)
      2 -> negotiate_fee(ctx)
      3 -> take_your_time(ctx)
      _ -> say_goodbye(ctx)
    end
  end

  defp apply_for_enrollment(ctx) do
    cond do
      job_level(ctx) < 40 ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes("I'm sorry, but you haven't met the basic requirements yet.")
        |> mes("Please go study more and reach Mage job level 40 first.")
        |> close()

      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes(
          "You have unused skill points left. Please go learn all those skills you've been planning to learn."
        )
        |> mes("We do not accept any ambiguous candidates.")
        |> close()

      true ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes("Very well. Let's complete your application form.")
        |> mes("Please put your signature here.")
        |> next()
        |> sign_application()
        |> collect_registration_fee()
    end
  end

  defp sign_application(ctx) do
    {ctx, _} = select(ctx, String.split(to_string(char_name(ctx, 0)), ":"))

    ctx
    |> mes("[Metheus Sylphe]")
    |> mes("Your name is ... #{char_name(ctx, 0)}. It's a very nice name.")
    |> next()
  end

  defp collect_registration_fee(ctx) do
    if job_level(ctx) == 50 do
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("Oh, you've mastered the Mage job! You're great!! *Clap Clap Clap*")
      |> mes("In reward for your great effort, you will be exempt from the registration fee!")
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("Yes, everything's ready.")
      |> mes("Next, you will take an entrance test.")
      |> set_char_var(:SAGE_Q, 4)
      |> setquest(2041)
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("Please visit Professor Claytos.")
      |> mes("He's in the left room.")
      |> close()
    else
      {ctx, payment} =
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes("Will you pay the registration fee with 70,000 zeny?")
        |> mes(
          "Or will you give me ^3355FFOld Magicbook^000000 and ^3355FFNecklace of Wisdom^000000?"
        )
        |> next()
        |> select(["Pay 70,000 zeny.", "Give him Old Magicbook and Necklace of Wisdom."])

      if payment == 1 do
        pay_full_fee(ctx)
      else
        hand_over_fee_items(ctx)
      end
    end
  end

  defp pay_full_fee(ctx) do
    if zeny(ctx) > 69_999 do
      ctx
      |> pay_zeny(70_000)
      |> mes("[Metheus Sylphe]")
      |> mes("Thank you, your application has been accepted.")
      |> mes("Next, you will take an entrance test.")
      |> set_char_var(:SAGE_Q, 4)
      |> setquest(2041)
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("Please visit Professor Claytos.")
      |> mes("He's in the left room.")
      |> close()
    else
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("What a shame! It seems you didn't bring enough money for tuition.")
      |> mes("Please make sure you have at least 70,000 zeny to enroll in classes.")
      |> close()
    end
  end

  defp hand_over_fee_items(ctx) do
    if count_item(ctx, 1006) > 0 and count_item(ctx, 1007) > 0 do
      ctx
      |> delitem(1006, 1)
      |> delitem(1007, 1)
      |> mes("[Metheus Sylphe]")
      |> mes("Thank you, your application has been accepted.")
      |> mes("Next, you will take the entrance test.")
      |> set_char_var(:SAGE_Q, 4)
      |> setquest(2041)
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("Please visit Professor Claytos.")
      |> mes("He's in the left room.")
      |> close()
    else
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("Umm...It seems you didn't bring any of those?")
      |> mes("I suppose you left them somewhere behind. Please go get them, and then come back.")
      |> close()
    end
  end

  defp negotiate_fee(ctx) do
    cond do
      job_level(ctx) < 40 ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes(
          "Before we talk about the registration fee, it seems you haven't met the basic requirement yet, Mage job level 40."
        )
        |> mes("Please go study more, and then come back to enroll.")
        |> close()

      job_level(ctx) == 50 ->
        waive_fee_for_master_mage(ctx)

      zeny(ctx) > 43_210 ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes(
          "Well, I can't help you with that issue. If you don't have the fee, you are not allowed to enter the academy."
        )
        |> mes(
          "Even if you may think it's absurdly expensive, it's a justifiable price to pay in order to become a Sage."
        )
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes(
          "Alternatively, you could try to find ^3355FFOld Magicbook^000000 and ^3355FFNecklace of Wisdom^000000."
        )
        |> mes("If you don't wish to do that, you must save some money for the registration fee.")
        |> next()
        |> mes("[Metheus Sylphe]")
        |> mes("Goodbye, and have a good day.")
        |> close()

      true ->
        offer_discount(ctx)
    end
  end

  defp waive_fee_for_master_mage(ctx) do
    ctx
    |> mes("[Metheus Sylphe]")
    |> mes(
      "Well, I can't help you with that issue. If you don't have the fee, you are not allowed to enter the academy."
    )
    |> mes(
      "Even if you might think it's absurdly expensive, it's a justifiable price to pay in order to become a Sage."
    )
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("Anyway... oh! You mastered the Mage job! You're truly exemplary!! *Clap Clap Clap*.")
    |> mes("As a reward for your great effort, you will be exempt from the registration fee!")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("Okay, let's complete the application form.")
    |> mes("Please put your signature here.")
    |> next()
    |> sign_application()
    |> mes("[Metheus Sylphe]")
    |> mes("Yes, everything's ready.")
    |> mes("Next, you will take the entrance test.")
    |> set_char_var(:SAGE_Q, 4)
    |> setquest(2041)
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("Please visit professor Claytos.")
    |> mes("He's in the left room.")
    |> close()
  end

  defp offer_discount(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("Oh, I guess you don't have enough money?")
      |> mes("Under the existing provisions, you must pay 70,000 zeny for the application...")
      |> next()
      |> select(["Please...is there any way?", "Ok, I will come back later."])

    if choice == 1 do
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("Hmmm...then I shall offer a special option!")
      |> mes(
        "You will pay 30,000 zeny and bring some items as compensation for the tuition discount."
      )
      |> next()
      |> assign_discount_items(Enum.random(1..3))
      |> mes("I am sure it's a very reasonable option for you.")
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes(
        "Ah yes, before gathering all of those items, if you happen to have 70,000 zeny, I will be more than happy to receive the full payment."
      )
      |> mes("That is, after all, our original policy.")
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes(
        "Alternatively, you can bring me ^3355FFOld Magicbook^000000 and ^3355FFNecklace of Wisdom^000000."
      )
      |> mes("Goodbye, and have a good day.")
      |> close()
    else
      take_your_time(ctx)
    end
  end

  defp assign_discount_items(ctx, 1) do
    ctx
    |> set_char_var(:SAGE_Q, 1)
    |> setquest(2043)
    |> mes("[Metheus Sylphe]")
    |> mes("Please gather the following items.")
    |> mes("50 ^3355FFFeather of Birds^000000")
    |> mes("50 ^3355FFFluff^000000")
    |> mes("25 ^3355FFIron Ore^000000")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes(
      "If you bring those items, your tuition will be 30,000 zeny, in lieu of the original 70,000 zeny fee."
    )
  end

  defp assign_discount_items(ctx, 2) do
    ctx
    |> set_char_var(:SAGE_Q, 2)
    |> setquest(2044)
    |> mes("[Metheus Sylphe]")
    |> mes("Please gather the following items.")
    |> mes("50 ^3355FFClover^000000")
    |> mes("50 ^3355FFFeather^000000")
    |> mes("25 ^3355FFSquid Ink^000000")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes(
      "If you bring the aforementioned items, the tuition fee will be 30,000 zeny, rather than the original 70,000 zeny fee."
    )
  end

  defp assign_discount_items(ctx, 3) do
    ctx
    |> set_char_var(:SAGE_Q, 3)
    |> setquest(2045)
    |> mes("[Metheus Sylphe]")
    |> mes("Please gather the following items.")
    |> mes("50 ^3355FFFeather of Birds^000000")
    |> mes("50 ^3355FFFluff^000000")
    |> mes("50 ^3355FFClover^000000")
    |> mes("50 ^3355FFFeather^000000")
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes(
      "If you bring those items, your tuition will only be 30,000 zeny, instead of the original 70,000 zeny fee."
    )
  end

  defp assign_discount_items(ctx, _roll), do: ctx

  defp discount_requirements(1), do: [{916, 50}, {914, 50}, {1002, 25}]
  defp discount_requirements(2), do: [{705, 50}, {949, 50}, {1024, 25}]
  defp discount_requirements(3), do: [{916, 50}, {914, 50}, {705, 50}, {949, 50}]

  defp collect_discounted_fee(ctx, requirements) do
    checked = Enum.take(requirements, length(requirements) - 1)

    if Enum.all?(checked, fn {item, amount} -> count_item(ctx, item) >= amount end) do
      ctx =
        if zeny(ctx) > 29_999 do
          checked
          |> Enum.reduce(ctx, fn {item, amount}, ctx -> delitem(ctx, item, amount) end)
          |> pay_zeny(30_000)
          |> mes("[Metheus Sylphe]")
          |> mes("Well done. Let me proceed with your application request.")
          |> set_char_var(:SAGE_Q, 4)
          |> next()
        else
          ctx
        end

      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("I am sorry to say that you are not ready yet.")
      |> mes(
        "Although you brought all of the items, the money you have now is less than 30,000 zeny."
      )
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes(
        "As I told you before, you must bring all of those items, as well as the 30,000 zeny together."
      )
      |> mes("Please make sure that you have the required items and money.")
      |> close()
    else
      remind_discount_items(ctx, requirements)
    end
  end

  defp remind_discount_items(ctx, requirements) do
    [first, second, third | _] = lines = Enum.map(requirements, &requirement_line/1)

    ctx =
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("I am sorry to say that it seems you didn't bring all of the required items.")
      |> mes("I shall remind you what to bring, in case you have forgotten.")
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("Please bring the following items to me.")
      |> mes(first)
      |> mes(second)
      |> mes(third)

    ctx =
      if get_char_var(ctx, :SAGE_Q, 0) == 3 do
        mes(ctx, Enum.at(lines, 3))
      else
        ctx
      end

    ctx
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes(
      "If you bring all of these items, your tuition fee will be reduced from 70,000 zeny to 30,000 zeny."
    )
    |> mes("Good luck.")
    |> close()
  end

  defp requirement_line({item, amount}),
    do: "#{amount} ^3355FF#{Rathena.getitemname(item)}^000000"

  defp complete_application(ctx, discount_plan) do
    {ctx, _} =
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("Let's complete the application form.")
      |> mes("Please put your signature here.")
      |> next()
      |> select(String.split(to_string(char_name(ctx, 0)), ":"))

    ctx
    |> mes("[Metheus Sylphe]")
    |> remark_on_name(discount_plan)
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("Ah yes, everything is in readiness.")
    |> mes("Next, you will take an entrance test.")
    |> set_char_var(:SAGE_Q, 4)
    |> promote_application_quest()
    |> next()
    |> mes("[Metheus Sylphe]")
    |> mes("Please visit Professor Claytos.")
    |> mes("He's in the left room.")
    |> close()
  end

  defp remark_on_name(ctx, 1),
    do: mes(ctx, "Your name is ... #{char_name(ctx, 0)}. It's a very nice name.")

  defp remark_on_name(ctx, 2),
    do: mes(ctx, "Your name is ... #{char_name(ctx, 0)}. It sounds very sagacious.")

  defp remark_on_name(ctx, 3),
    do: mes(ctx, "Your name is ... #{char_name(ctx, 0)}. Interesting name.")

  defp remark_on_name(ctx, _discount_plan), do: ctx

  defp promote_application_quest(ctx) do
    cond do
      checkquest(ctx, 2043) != -1 -> changequest(ctx, 2043, 2041)
      checkquest(ctx, 2044) != -1 -> changequest(ctx, 2044, 2041)
      checkquest(ctx, 2045) != -1 -> changequest(ctx, 2045, 2041)
      true -> setquest(ctx, 2041)
    end
  end
end
