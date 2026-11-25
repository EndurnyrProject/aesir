defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.KafraEmployee155240 do
  @moduledoc """
  Benith directs the player's rescue mission for the Secret Wing.

  ## Behavior

  - Assigns the rescue and receives Jargeah's information.
  - Returns the file for delivery to the president.

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
        map: "aldeba_in",
        x: 155,
        y: 240,
        dir: 5,
        sprite: 859,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "Kafra Employee#l2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7343, 1}]) != 1 -> overweight(ctx)
      get_char_var(ctx, :lhz_boss, 0) < 17 -> explain_election(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 17 -> meet_benith(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 18 -> remind_rescue(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 19 -> receive_file(ctx)
      get_char_var(ctx, :lhz_boss, 0) == 20 -> return_file(ctx)
      true -> greeting(ctx)
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp explain_election(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Welcome to")
    |> mes("Kafra Headquarters.")
    |> mes("What's new with Kafra?")
    |> mes("Glad you asked. Right now,")
    |> mes("we're developing a brand new")
    |> mes("program with Cool Event Corp.")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("This new program will")
    |> mes("provide a direct teleport")
    |> mes("service to dungeons for")
    |> mes("the convenience of our")
    |> mes("valued customers. Is")
    |> mes("that not... exciting?")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("Due to technical issues,")
    |> mes("Kafra Corp and Cool Event")
    |> mes("Corp cannot provide teleport")
    |> mes("services to the same dungeon,")
    |> mes("so one common teleport service")
    |> mes("provider will be selected.")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("Therefore, elections will")
    |> mes("be held to determine which")
    |> mes("company will provide this")
    |> mes("Dungeon Teleport Service.")
    |> mes("Please check the eligibility")
    |> mes("requirements before voting.")
    |> close()
  end

  defp meet_benith(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome to")
      |> mes("Kafra Headquarters.")
      |> mes("What's new with Kafra?")
      |> mes("Glad you asked. Right now,")
      |> mes("we're developing a brand new")
      |> mes("program with Cool Event Corp.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("This new program will")
      |> mes("provide a direct teleport")
      |> mes("service to dungeons for")
      |> mes("the convenience of our")
      |> mes("valued customers. Is")
      |> mes("that not... exciting?")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Due to technical issues,")
      |> mes("Kafra Corp and Cool Event")
      |> mes("Corp cannot provide teleport")
      |> mes("services to the same dungeon,")
      |> mes("so one common teleport service")
      |> mes("provider will be selected.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("We'd like to inform")
      |> mes("you that the customers")
      |> mes("will decide the teleport")
      |> mes("service provider through")
      |> mes("an election. Your vote will")
      |> mes("be much appreciated.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Remember to take part")
      |> mes("in the polls that will be")
      |> mes("taking place in the cities")
      |> mes("of Prontera and Juno.")
      |> mes("Happy voting.")
      |> next()
      |> select(["Okay.", "I can't wait!"])

    case choice do
      1 -> ask_identity(ctx)
      2 -> appreciate_vote(ctx)
      _ -> ctx
    end
  end

  defp ask_identity(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Uh oh...")
      |> mes("Did you have a question?")
      |> mes("In all honesty, I don't know")
      |> mes("very much about the services")
      |> mes("Kafra offers. My work is...")
      |> mes("I'm in a different department.")
      |> next()
      |> select(["Oh, that's okay then.", "Are you Benith..?"])

    case choice do
      1 ->
        ctx
        |> mes("[Kafra Employee]")
        |> mes("*Whew!*")
        |> mes("Oh good. Well, if you")
        |> mes("do have any questions")
        |> mes("about the Kafra Services,")
        |> mes("please ask one of the regular")
        |> mes("Kafra Employees. Thank you.")
        |> close()

      2 ->
        identify_benith(ctx)

      _ ->
        ctx
    end
  end

  defp identify_benith(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Benith]")
      |> mes("Yes, that's me.")
      |> mes("Is there anything")
      |> mes("that I can do for you?")
      |> next()
      |> select(["No, not really.", "Show Membership Card."])

    case choice do
      1 -> ctx |> mes("[Benith]") |> mes("Really?") |> mes("Okay, then.") |> close()
      2 -> show_card(ctx)
      _ -> ctx
    end
  end

  defp show_card(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7348)) do
      ctx
      |> mes("^3355FFWait...")
      |> mes("You can't show")
      |> mes("your ''Secret Wing''")
      |> mes("Membership Card")
      |> mes("if you don't have it!^000000")
      |> close()
    else
      ctx
      |> mes("[Benith]")
      |> mes("Oh, I've been waiting")
      |> mes("for you. Finally, I can")
      |> mes("drop this promotional")
      |> mes("pretense and get down")
      |> mes("to business and tell you")
      |> mes("about your mission.")
      |> next()
      |> mes("[Benith]")
      |> mes("As an experienced")
      |> mes("adventurer, your specialty")
      |> mes("is in retrieving items and")
      |> mes("fighting against monsters.")
      |> mes("We have a rescue mission")
      |> mes("that suits your expertise.")
      |> next()
      |> mes("[Benith]")
      |> mes("One of our special")
      |> mes("agents got into an")
      |> mes("accident and is stuck")
      |> mes("in ^FF0000Grim Reaper's Valley^000000,")
      |> mes("located somewhere between")
      |> mes("Einbroch and Lighthalzen.")
      |> next()
      |> mes("[Benith]")
      |> mes("Our agent, Jargeah,")
      |> mes("is reported to be hiding")
      |> mes("near a broken bridge there.")
      |> mes("All of our other agents are")
      |> mes("assigned on other missions,")
      |> mes("so you're all he has right now.")
      |> next()
      |> mes("[Benith]")
      |> mes("He's seriously wounded,")
      |> mes("so please hurry before")
      |> mes("the enemy can get to him...")
      |> set_char_var(:lhz_boss, 18)
      |> changequest(12_019, 12_020)
      |> close()
    end
  end

  defp appreciate_vote(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("That makes one of u--")
    |> mes("I mean, your participation")
    |> mes("is very much appreciated.")
    |> mes("Remember that Kafra is")
    |> mes("always on your side.")
    |> close()
  end

  defp remind_rescue(ctx) do
    ctx
    |> mes("[Benith]")
    |> mes("Please hurry and save")
    |> mes("Jargeah. If the enemy")
    |> mes("gets to him before we")
    |> mes("do, all his efforts, as well")
    |> mes("as his life, may be forfeit.")
    |> next()
    |> mes("[Benith]")
    |> mes("You should be able to")
    |> mes("find him near a broken")
    |> mes("bridge in Grim Reaper's")
    |> mes("Valley, which is located")
    |> mes("somewhere between")
    |> mes("Einbroch and Lighthalzen.")
    |> close()
  end

  defp receive_file(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7343)) do
      ctx
      |> mes("[Benith]")
      |> mes("Please hurry!")
      |> mes("I don't want the enemy")
      |> mes("to find Jargeah before")
      |> mes("we do! His life and the")
      |> mes("Secret Wing are at stake!")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("[Benith]")
        |> mes("Great, you're back,")
        |> mes("and you even have the")
        |> mes("information that Jargeah")
        |> mes("managed to obtain. But...")
        |> mes("Where's Jargeah? Is he...?")
        |> next()
        |> select(["He's in a better place."])

      case choice do
        1 ->
          ctx
          |> mes("[Benith]")
          |> mes("...")
          |> mes("......")
          |> next()
          |> mes("[Benith]")
          |> mes("What...?! Noooo!")
          |> mes("Comrade Jargeah!")
          |> mes("I swear to you your")
          |> mes("death won't be in vain!")
          |> mes("Why did another good man")
          |> mes("have to die? Answer me!!")
          |> next()
          |> mes("[Benith]")
          |> mes("I can't... No. We must")
          |> mes("first honor Jargeah's noble")
          |> mes("sacrifice before we can allow ourselves the luxury of mourning")
          |> mes("our loss. Let me read these files first before you deliver them...")
          |> delitem(7343, 1)
          |> set_char_var(:lhz_boss, 20)
          |> close()

        _ ->
          ctx
      end
    end
  end

  defp return_file(ctx) do
    ctx
    |> mes("[Benith]")
    |> mes("Alright. Please take")
    |> mes("this file to ^FF0000him^000000 now.")
    |> mes("I believe you know")
    |> mes("whom I am talking about.")
    |> mes("The Secret Wing is counting")
    |> mes("on you, brave adventurer.")
    |> set_char_var(:lhz_boss, 21)
    |> give_item(7343, 1)
    |> changequest(12_021, 12_022)
    |> next()
    |> mes("[Benith]")
    |> mes("I swear by my father's")
    |> mes("grave that the tears I shed")
    |> mes("for Jargeah will only be")
    |> mes("matched by the blood I will")
    |> mes("spill in holy retribution.")
    |> mes("Jargeah, watch over me!")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Benith]")
    |> mes("W-welcome to the")
    |> mes("Kafra Headquarters.")
    |> mes("What's new with Kafra?")
    |> mes("^333333Glad... You... Asked...^000000")
    |> close()
  end
end
