defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.Guide do
  @moduledoc """
  Ditze explains Thanatos Tower and recruits temporary employees.

  ## Behavior

  - Explains the tower and its monsters to visitors.
  - Offers a contract granting access to the higher floors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "tha_t01", x: 149, y: 78, dir: 4, sprite: 90, name: "Guide", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :thana_tower, 0) == 0 do
      {ctx, choice} =
        ctx
        |> mes("[Ditze]")
        |> mes("Welcome to Thanatos Tower.")
        |> mes("The tower's reconstruction is")
        |> mes("a Rekenber Corporation project,")
        |> mes("and the 1st and 2nd floors are")
        |> mes("now open to the public. So")
        |> mes("how may I help you today?")
        |> next()
        |> select(["Tower Information", "Temporary Work Contract", "Cancel"])

      case choice do
        1 ->
          {ctx, topic} =
            ctx
            |> mes("[Ditze]")
            |> mes("When this tower was built,")
            |> mes("who built it, and its purpose")
            |> mes("are all mysteries. There are")
            |> mes("many rumors about it being a")
            |> mes("Mage lab, a hero's momunent,")
            |> mes("or a demon fortress...")
            |> next()
            |> mes("[Ditze]")
            |> mes("The Rekenber Corporation has")
            |> mes("been researching the origin of")
            |> mes("this tower, but has not yet been able to confirm anything. Although")
            |> mes("we've lost many researchers to the tower monsters, we won't give up!")
            |> next()
            |> mes("[Ditze]")
            |> mes("Rekenber is convinced that this")
            |> mes("tower holds many secrets, and")
            |> mes("successfully reconstructed the")
            |> mes("first 2 floors of this tower in")
            |> mes("the pursuit of this knowledge.")
            |> next()
            |> mes("[Ditze]")
            |> mes("Currently, we are focused on")
            |> mes("reconstructing the tower's 3rd")
            |> mes("and 4th floors. Luckily, many")
            |> mes("adventurers are exterminating")
            |> mes("the monsters on those floors, working under temporary contracts.")
            |> next()
            |> mes("[Ditze]")
            |> mes("At this rate, we expect")
            |> mes("to complete reconstruction")
            |> mes("of the 3rd and 4th floors in")
            |> mes("the near future, bringing us")
            |> mes("closer to our goal of opening all 12 floors of Thanatos Tower.")
            |> next()
            |> select(["Tower Monsters?", "Temp Contract Work?", "......"])

          case topic do
            1 ->
              ctx
              |> mes("[Ditze]")
              |> mes("Yes, when we began")
              |> mes("reconstruction of the")
              |> mes("Thanatos Tower, these")
              |> mes("monsters that look like angels")
              |> mes("just appeared out of nowhere")
              |> mes("to attack all the workers.")
              |> next()
              |> mes("[Ditze]")
              |> mes("At first, witnesses thought")
              |> mes("that these monsters might")
              |> mes("be, you know, actual angels.")
              |> mes("But if they were, why were they")
              |> mes("attacking for no reason?")
              |> next()
              |> mes("[Ditze]")
              |> mes("Anyway, we asked the Juno ")
              |> mes("Sage Academy to investigate")
              |> mes("them, and they confirmed that")
              |> mes("these angelic creatures are true monsters--their resemblance to")
              |> mes("angels is merely coincidence.")
              |> close()

            2 ->
              contract_introduction(ctx)

            3 ->
              ctx
              |> mes("[Ditze]")
              |> mes("To develop the floors above")
              |> mes("the 2nd floor, we're going to")
              |> mes("need as many temp contract")
              |> mes("workers as we can hire. Why")
              |> mes("don't you consider working")
              |> mes("for us under a temp contract?")
              |> close()

            _ ->
              ctx
          end

        2 ->
          contract_introduction(ctx)

        3 ->
          ctx
          |> mes("[Ditze]")
          |> mes("Well, if you have any")
          |> mes("questions, feel free to")
          |> mes("ask me later. My name is")
          |> mes("Ditze Lappa. Have a good day!")
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Ditze]")
      |> mes("For more detailed information")
      |> mes("about monster exterminations,")
      |> mes("please ask the 2nd Floor Guide")
      |> mes("and the Guide next to me. Well,")
      |> mes("we hope you enjoy your experience working with Rekenber Corporation~")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp contract_introduction(ctx) do
    ctx
    |> mes("[Ditze]")
    |> mes("You may have already heard")
    |> mes("from the Tower Keeper, but")
    |> mes("we're contracting adventurers to exterminate the tower monsters")
    |> mes("in the 3rd and higher levels on")
    |> mes("a temporary employee basis.")
    |> next()
    |> mes("[Ditze]")
    |> mes("I'm in charge of hiring")
    |> mes("temp contract workers, so")
    |> mes("talk to me if you're interested. Only temp workers are allowed")
    |> mes("to access the higher levels")
    |> mes("here in Thanatos Tower.")
    |> next()
    |> contract()
  end

  defp contract(ctx) do
    {ctx, decision} = select(ctx, ["Maybe next time", "Sure, I'd like to work for you."])

    case decision do
      1 ->
        ctx
        |> mes("[Ditze]")
        |> mes("Well, alright.")
        |> mes("But come and talk to")
        |> mes("me as soon as you decide")
        |> mes("that you want to help with")
        |> mes("the tower reconstruction by")
        |> mes("working for Rekenber.")
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Ditze]")
          |> mes("That's great!")
          |> mes("Would you please fill")
          |> mes("out this employment")
          |> mes("agreement first? Let's")
          |> mes("see. Your name is...")

        {ctx, _} =
          ctx |> mes(Rathena.concat(char_name(ctx, 0), ", right?")) |> next() |> select(["Yes"])

        ctx =
          ctx
          |> mes("[Ditze]")
          |> mes("Alright, please read")
          |> mes("this agreement carefully.")
          |> mes("If you agree with all of")
          |> mes("the conditions, go ahead")
          |> mes("and just sign the bottom.")
          |> next()
          |> mes("^3355FFDitze hands you the")
          |> mes("Employment Agreement")
          |> mes("document for you to read.^000000")
          |> next()
          |> mes("- Employment Agreement -")
          |> mes(" ")
          |> mes("1. This employment agreement")
          |> mes("is effective between Rekenber")

        {ctx, signature} =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("Corporation (''Employer'') and ", char_name(ctx, 0)),
              "(''Employee'')."
            )
          )
          |> mes("1-1. This employment agreement")
          |> mes("is classified as a Mercernary")
          |> mes("contract between both parties.")
          |> mes("2. The terms of this contract")
          |> mes("immediately take effect once")
          |> mes("it is signed by both parties")
          |> mes("(Employer and Employee).")
          |> mes("3. When the Employee performs")
          |> mes("a mission, the mission results")
          |> mes("must be verified with acceptible physical proof that must be")
          |> mes("presented to the Employer.")
          |> mes("3-1. Please refer to Section")
          |> mes("7A for examples of acceptible")
          |> mes("proof of monster extermination.")
          |> mes("3-2. Acceptible proof is")
          |> mes("determined and defined by a")
          |> mes("representative of the Employer.")
          |> mes("4. Employer will allot rewards")
          |> mes("to Employees after receiving")
          |> mes("extermination proof.")
          |> mes("4-1. Possible rewards for")
          |> mes("monster exterminations may")
          |> mes("include the following.")
          |> mes(".................................................")
          |> mes(".................................................")
          |> mes(".................................................")
          |> mes(".................................................")
          |> mes(".................................................")
          |> mes("13. This contract's terms are")
          |> mes("only applicable witin Thanatos")
          |> mes("Tower.")
          |> mes("14. Employees will receive")
          |> mes("a discount on the Entry Fee")
          |> mes("to the Thanatos Tower.")
          |> mes(" ")
          |> mes(" ")
          |> mes(" ")
          |> mes("Employer Signature____________")
          |> mes("Employee Signature____________")
          |> next()
          |> select(["Sign", "Don't Sign"])

        case signature do
          1 ->
            ctx
            |> mes("^3355FFYou sign two copies of the")
            |> mes("Employment Agreement.^000000")
            |> next()
            |> mes("[Ditze]")
            |> mes("Thank you. Now, you are")
            |> mes("an official employee of the")
            |> mes("Rekenber Corporation! Well,")
            |> mes("within the limits of this tower")
            |> mes("anyway. This contract doesn't")
            |> mes("apply outside of this place.")
            |> next()
            |> mes("[Ditze]")
            |> mes("From now on, you can talk")
            |> mes("to the 2nd Floor Guide to")
            |> mes("enter the 3rd Floor. If you")
            |> mes("have any mission reward")
            |> mes("questions, please ask ^3355FFLiei^000000.")
            |> next()
            |> mes("[Ditze]")
            |> mes("If you want to check")
            |> mes("more information about")
            |> mes("your work, please talk")
            |> mes("to the 2nd Floor Guide.")
            |> mes("Thank you, and welcome")
            |> mes("to the Rekenber Corporation~")
            |> set_char_var(:thana_tower, 1)
            |> close()

          2 ->
            ctx
            |> mes("[Ditze]")
            |> mes("Oh? Was there an article")
            |> mes("within the contract that you")
            |> mes("disagreed with? Hm. Well,")
            |> mes("that's fine. But if you change")
            |> mes("your mind, please come back")
            |> mes("and ask me anytime. Thank you~")
            |> close()

          _ ->
            ctx
        end

      _ ->
        ctx
    end
  end
end
