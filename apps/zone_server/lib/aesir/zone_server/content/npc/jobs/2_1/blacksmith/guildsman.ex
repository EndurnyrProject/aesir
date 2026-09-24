defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.Guildsman do
  @moduledoc """
  Runs the Blacksmith Guild's application desk and promotes Merchants to Blacksmith.

  ## Behavior

  - Greets reborn characters, third classes, and other classes with flavor dialogue.
  - Enrolls Merchants of Job Level 40 or higher with no unused skill points in the job quest.
  - Sends applicants who passed the delivery test on to the guild quiz.
  - Changes quiz graduates to Blacksmith, takes the Hammer of Blacksmith, and rewards Steel
    (more for applicants above Job Level 48).

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - Komurka
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - L0ne_W0lf
    - Yommy
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 18,
        y: 28,
        dir: 4,
        sprite: 731,
        name: "Guildsman",
        scope: :shared,
        unique_name: "Guildsman#BLS"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if upper(ctx) == 1 do
      greet_reborn(ctx)
    else
      welcome(ctx)
    end
  end

  defp greet_reborn(ctx) do
    ctx
    |> mes("[Altiregen]")
    |> mes(
      "Hey hey. I don't have time for chit-chat, I'm a pretty busy guy. There's all these Merchants working hard to become Blacksmiths."
    )
    |> next()
    |> mes("[Altiregen]")
    |> mes("Wait a minute, I think I've met you before.")
    |> mes("Ummm.....")
    |> next()
    |> mes("[Altiregen]")
    |> mes(
      "Are you the one who broke my weapon and ran away? Or are you the one who tortured me so that I'd forge a weapon for you? Why can't I remember?"
    )
    |> next()
    |> mes("[Altiregen]")
    |> mes(".......")
    |> mes("I can't remember who you are for the life of me. Is this deja vu?")
    |> next()
    |> mes("[Altiregen]")
    |> mes(
      "Argh!! This is really bugging me! But still, I can sense that there's something special about you. Oh well, whatever. Have a good day~"
    )
    |> close()
  end

  defp welcome(ctx) do
    ctx =
      ctx
      |> mes("[Altiregen]")
      |> mes("Welcome!")
      |> mes("We are Workers of Steel,")
      |> mes("the Blacksmith Guild.")
      |> next()
      |> mes("[Altiregen]")
      |> mes("We pour the fervor")
      |> mes("and passion of our souls into")
      |> mes("our craft. Our skills of melting metal into new weapons")
      |> mes("and tools is truly a form of art!")

    if Rathena.job_id(base_class(ctx)) >= Rathena.job_id(:thief) do
      close(ctx)
    else
      ctx |> next() |> respond_to_class()
    end
  end

  defp respond_to_class(ctx) do
    cond do
      Rathena.job_id(class(ctx)) >= Rathena.job_id(:rune_knight) and
          Rathena.job_id(class(ctx)) <= Rathena.job_id(:baby_mechanic2) ->
        ctx
        |> mes("[Altiregen]")
        |> mes(
          "You... look like a stranger. But somehow it seems that you're related to our guild. Haha~"
        )
        |> mes("Am I right?")
        |> close()

      base_class?(ctx, :novice) ->
        greet_novice(ctx)

      base_class?(ctx, :swordman) ->
        ctx
        |> mes("[Altiregen]")
        |> mes(
          "Oh, are you interested in having a weapon forged? I'm sorry to disappoint you, but I actually have a lot of business to attend to."
        )
        |> close()

      base_class?(ctx, :archer) ->
        ctx
        |> mes("[Altiregen]")
        |> mes("Oh...")
        |> mes(
          "There's not much we can offer you here. And you can't really help out around here unless you know how to make stuff..."
        )
        |> close()

      base_class?(ctx, :mage) ->
        ctx
        |> mes("[Altiregen]")
        |> mes(
          "Oh? What's a magic user doing here? I'm surprised. Usually this kind of rough work is beneath you intellectual types."
        )
        |> close()

      base_class?(ctx, :acolyte) ->
        ctx
        |> mes("[Altiregen]")
        |> mes(
          "Oh! Am I correct in assuming you're a member of the Clergy? Would you please bless me before you leave!"
        )
        |> close()

      base_class?(ctx, :thief) ->
        ctx
        |> mes("[Altiregen]")
        |> mes("I'm sorry...")
        |> mes(
          "But there really isn't anything for you to steal here. Well, there are the Daggers we keep in the back, but..."
        )
        |> close()

      base_job?(ctx, :alchemist) ->
        ctx
        |> mes("[Altiregen]")
        |> mes("So how's the pharmacy business going on recently?")
        |> mes("Well, my forging business does not seem to grow any longer.")
        |> close()

      base_job?(ctx, :blacksmith) ->
        ctx
        |> mes("[Altiregen]")
        |> mes("Oh! Long time no see.")
        |> mes(
          "Have you come to purchase supplies from Christopher? These days I'm stuck behind this desk. My body's itching to strike the ol' anvil."
        )
        |> close()

      base_job?(ctx, :merchant) ->
        talk_to_merchant(ctx)

      true ->
        ctx
    end
  end

  defp base_class?(ctx, job), do: Rathena.job_id(base_class(ctx)) == Rathena.job_id(job)

  defp base_job?(ctx, job), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(job)

  defp greet_novice(ctx) do
    ctx = mes(ctx, "[Altiregen]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0) do
        ctx |> mes("Oh~") |> mes("what a very") |> mes("pretty lady!")
      else
        ctx
      end

    ctx
    |> mes("Are you interested in")
    |> mes("becoming a Blacksmith?")
    |> next()
    |> mes("[Altiregen]")
    |> mes(
      "First, you must become a Merchant before you can become a Blacksmith. Go to the city of Alberta to learn the Merchant trade."
    )
    |> close()
  end

  defp talk_to_merchant(ctx) do
    if Rathena.truthy?(skill_point(ctx)) do
      refuse_unused_skill_points(ctx)
    else
      quest_progress(ctx, get_char_var(ctx, :BSMITH_Q, 0))
    end
  end

  defp quest_progress(ctx, 0), do: offer_application(ctx)

  defp quest_progress(ctx, step) when step > 0 and step < 8 do
    ctx
    |> mes("[Altiregen]")
    |> mes("You haven't left yet?")
    |> mes(
      "Go to Einbech and find ^8E6B23Geschupenschte^000000. Finish helping him out, and when you're done, come back to me."
    )
    |> close()
  end

  defp quest_progress(ctx, step) when step > 8 and step < 15 do
    ctx
    |> mes("[Altiregen]")
    |> mes(
      "Was the work you did for ^8E6B23Geschupenschte^000000 to your liking? He's known for being pretty exacting..."
    )
    |> close()
  end

  defp quest_progress(ctx, 15), do: announce_quiz(ctx)

  defp quest_progress(ctx, 16) do
    ctx
    |> mes("[Altiregen]")
    |> mes("Um? Haven't you talk to the guildsman yet?")
    |> mes("If you haven't, I suggest you to do so as soon as possible.")
    |> close()
  end

  defp quest_progress(ctx, 17) do
    if count_item(ctx, 1005) > 0 and job_level(ctx) > 39 do
      promote(ctx)
    else
      ctx
    end
  end

  defp quest_progress(ctx, _step), do: ctx

  defp refuse_unused_skill_points(ctx) do
    ctx
    |> mes("[Altiregen]")
    |> mes(
      "You can't change to the Blacksmith Job Class without first using all your skill points. Please come back after wisely using your skill points."
    )
    |> close()
  end

  defp offer_application(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Altiregen]")
      |> mes("Why don't you stop struggling")
      |> mes("to make zeny as a Merchant and")
      |> mes("join the elite Blacksmith class?")
      |> mes("If you're interested, fill out this application with your name")
      |> mes("and Job Level.")
      |> next()
      |> select([
        "Fill out Application.",
        "What are the requirements?",
        "Um, I need to think about it."
      ])

    case choice do
      1 ->
        fill_out_application(ctx)

      2 ->
        explain_requirements(ctx)

      3 ->
        ctx
        |> mes("[Altiregen]")
        |> mes("Hmmm...")
        |> mes("Well, I hope")
        |> mes("to see you again.")
        |> close()

      _ ->
        ctx
    end
  end

  defp fill_out_application(ctx) do
    cond do
      Rathena.truthy?(skill_point(ctx)) ->
        refuse_unused_skill_points(ctx)

      job_level(ctx) > 39 and get_char_var(ctx, :BSMITH_Q, 0) == 0 ->
        ctx
        |> mes("[Altiregen]")
        |> mes("Hmmm...")
        |> mes("Looks like you")
        |> mes("meet the Job Level")
        |> mes("Requirement.")
        |> next()
        |> mes("[Altiregen]")
        |> mes(
          "You see, we don't accept just anybody into our guild. First, we only accept experienced Merchants with a true desire to become great Blacksmiths. Let's see..."
        )
        |> next()
        |> mes("^3355FF*Shuffling of papers*^000000")
        |> next()
        |> mes("[Altiregen]")
        |> mes("Hmmm...")
        |> mes(
          "One of our Blacksmiths in Einbech, ^8E6B23Geschupenschte^000000 has sent us word that he's short on help. Your first test of character will be to help him out."
        )
        |> next()
        |> set_char_var(:BSMITH_Q, 1)
        |> setquest(2000)
        |> mes("[Altiregen]")
        |> mes("Be careful")
        |> mes("and good luck!")
        |> close()

      job_level(ctx) < 40 ->
        ctx
        |> mes("[Altiregen]")
        |> mes(
          "Hmmm, it seems that you lack experience as a Merchant. We require that you are at least Job Level 40, you see."
        )
        |> next()
        |> mes("[Altiregen]")
        |> mes(
          "I feel bad turning you away after you've come so far, but rules are rules. Sorry to disappoint you, but we'll welcome you back once you're ready."
        )
        |> close()

      true ->
        explain_requirements(ctx)
    end
  end

  defp explain_requirements(ctx) do
    ctx
    |> mes("[Altiregen]")
    |> mes(
      "You want to know our requirements? First, you need to have Job Level 40 or higher as a Merchant. Second, you need to pass a test that will be given by the Blacksmith Guild."
    )
    |> next()
    |> mes("[Altiregen]")
    |> mes(
      "The test may consist of difficult tasks, but it's definitely not impossible. You will need to deliver certain items to different areas around the world"
    )
    |> mes("to complete the test.")
    |> close()
  end

  defp announce_quiz(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Altiregen]")
      |> mes("Great job!!")
      |> mes("You have passed")
      |> mes("the first test...")
      |> next()
      |> mes("[Altiregen]")
      |> mes("Hm? You look surprised.")
      |> mes("I guess you didn't know that there's more than one test. ")
      |> mes("Haha, but don't worry, you are not going to travel that far.")
      |> mes(
        "Please go talk to the guildsman inside the building for more details about your next test."
      )
      |> next()
      |> select(["I want to change my job quickly! But...oh well.", "Grrr! Enough is enough!"])

    if choice == 1 do
      ctx
      |> set_char_var(:BSMITH_Q, 16)
      |> changequest(2013, 2014)
      |> mes("[Altiregen]")
      |> mes(
        "I'm sorry, but I'm sure you understand, right? We can't just casually accept anybody into"
      )
      |> mes("our guild!")
      |> next()
      |> mes("[Altiregen]")
      |> mes("If we don't keep our standards,")
      |> mes("we won't be able to maintain the respectability of the Blacksmith Guild!")
      |> mes(
        "We can't embarass our guild in this manner! *Ahem* Anyway, you talk to the guildsman inside the building now."
      )
      |> close()
    else
      ctx
      |> mes("[Altiregen]")
      |> mes("Are you saying you're going")
      |> mes("to quit the application process? That's an insult to our guild!")
      |> mes(
        "Get out of here! With that kind of attitude, you can forget becoming a member of the Blacksmith Guild!"
      )
      |> next()
      |> mes("[Altiregen]")
      |> mes("You have no spirit!")
      |> mes("If you can't endure this, you'll never be a Blacksmith!")
      |> close()
    end
  end

  defp promote(ctx) do
    ctx = mes(ctx, "[Altiregen]")

    if Rathena.truthy?(ismounting(ctx)) do
      ctx
      |> mes("You are on a riding pet, so you cannot change your job.")
      |> mes("Please unequip your riding pet and try again!")
      |> close()
    else
      change_to_blacksmith(ctx)
    end
  end

  defp change_to_blacksmith(ctx) do
    ctx =
      mes(
        ctx,
        "Excellent, I can tell by the twinkle in your eye that you were successful. I can now bestow upon you the gift of the smithing, the art of the Blacksmith."
      )

    ctx =
      if checkquest(ctx, 2015) != -1 do
        changequest(ctx, 2015, 2016)
      else
        ctx
      end

    ctx = next(ctx)
    merchant_job_level = job_level(ctx)
    {ctx, _} = ctx |> jobchange(:blacksmith) |> FClearjobvar.call([])
    steel = if merchant_job_level > 48, do: 30, else: 5

    ctx
    |> mes("[Altiregen]")
    |> mes(
      "Always remember that we are creators, and artists over metals. Be wary that you do not fall into the pitfalls of selfishness"
    )
    |> mes("and greed.")
    |> next()
    |> delitem(1005, 1)
    |> completequest(2016)
    |> mes("[Altiregen]")
    |> mes("Here is a little")
    |> mes("gift to mark the")
    |> mes("beginning of your")
    |> mes("life as a Blacksmith.")
    |> mes("Congratulations!!!")
    |> give_item(999, steel)
    |> close()
  end
end
