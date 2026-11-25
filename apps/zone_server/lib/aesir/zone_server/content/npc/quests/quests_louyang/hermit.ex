defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Hermit do
  @moduledoc """
  Sun Mao recruits adventurers for Luoyang's revolutionary movement.

  ## Behavior

  - Enlists recruits and directs party leaders to gather eight members one at a time.
  - Assigns a smuggling mission and rewards the party leader for its completion.

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
    spawn: [%{map: "lou_in02", x: 77, y: 37, dir: 7, sprite: 824, name: "Hermit", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      not Rathena.truthy?(get_char_var(ctx, :QL_REVOL, 0)) -> invitation(ctx)
      party_leader?(ctx) == 1 -> leader(ctx)
      true -> member(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp invitation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sun Mao]")
      |> mes("Where there's a will,")
      |> mes("there's a way. When we")
      |> mes("work together, there's")
      |> mes("nothing we cannot do.")
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Will you lend us your power, and help us build a better future? Will you join our movement for social reform in Luoyang?"
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "It doesn't matter if you're a local or a foreigner. So long as we share the same goal of creating a better Luoyang, where everyone is treated as an equal."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes("My name...")
      |> mes("is Sun Mao.")
      |> mes(
        "This invitation may be sudden, but I am a man of action. I see in your face that you too despise injustice."
      )
      |> next()
      |> select([
        "What am I supposed to do?",
        "I will join you!",
        "Well, I'm just another tourist..."
      ])

    case choice do
      1 -> explain_cause(ctx)
      2 -> confirm_pledge(ctx)
      3 -> turn_away(ctx)
      _ -> ctx
    end
  end

  defp explain_cause(ctx) do
    ctx
    |> mes("[Sun Mao]")
    |> mes(
      "For now, we must recruit as many members as we can. When we're ready, we'll start a movement that will change Luoyang, and even the world!"
    )
    |> next()
    |> mes("[Sun Mao]")
    |> mes(
      "However, we currently do not have the manpower to carry out the plans we have laid out. We've been lucky the lord hasn't found us out yet."
    )
    |> next()
    |> mes("[Sun Mao]")
    |> mes(
      "I wish everyone would understand our intentions, but the people of this city are disunited. This is not the first time I have approached a foreigner for help..."
    )
    |> next()
    |> mes("[Sun Mao]")
    |> mes(
      "I suppose you understand the urgency of our cause, and our need to gather others who see the merit of our goals!"
    )
    |> close()
  end

  defp confirm_pledge(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "Oh, God must be on my side today and has sent you to me. Thank you for making the big decision..."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes("I shall then engrave your name")
      |> mes(
        "on this bloody pledge board. But before I do so, I shall ask once more. Do you truly wish to join us, through pain and bloodshed?"
      )
      |> next()
      |> select(["No, wait!", "I am 100% sure."])

    case choice do
      1 -> reconsider(ctx)
      2 -> join(ctx)
      _ -> ctx
    end
  end

  defp reconsider(ctx) do
    ctx
    |> mes("[Sun Mao]")
    |> mes(
      "I understand if you need time to decide. If you do decide to join us, please return. Time is on our side, after all."
    )
    |> close()
  end

  defp join(ctx) do
    ctx = ctx |> set_char_var(:QL_REVOL, 1) |> mes("[Sun Mao]")

    ctx =
      ctx
      |> mes(Rathena.concat(char_name(ctx, 0), "...!"))
      |> mes(
        "Your name is now engraved on this bloody pledge board. We will fight together to the death for Luoyang's future!"
      )
      |> next()

    {ctx, _} = getpartymember(ctx, getcharid(ctx, 1))

    ctx =
      set_temp_var(ctx, :partymember, get_server_temp_var(ctx, "partymembercount", 0))

    if party_leader?(ctx) == 1 or not Rathena.truthy?(get_temp_var(ctx, :partymember, 0)) do
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "Now, the most important thing for our cause is to gather more recruits and increase our numbers. Please find others who will join us in our fight."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "However, as to not arouse suspicion, bring only one new recruit at a time. Also, we suggest not to bring a friend in a party with you."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Now, I will wait for you here. Go forth and find others who wish for a better future for Luoyang!"
      )
      |> close()
    else
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "Please assist the people who fight behind you. As more are gathered, one of our comrades will inform you of further instructions."
      )
      |> close()
    end
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Sun Mao]")
    |> mes(
      "Are you...? I see, you may leave now. Do not reveal what you have seen or heard in this place."
    )
    |> next()
    |> mes("[Sun Mao]")
    |> mes(
      "If you're a real tourist, you do not want to get involved in our business, one way or another."
    )
    |> close()
  end

  defp leader(ctx) do
    if get_char_var(ctx, :QL_REVOL, 0) == 9 do
      ctx
      |> mes("[Sun Mao]")
      |> mes("Once again,")
      |> mes("thank you for")
      |> mes("your trouble.")
      |> mes("Go back safe.")
      |> close()
    else
      {ctx, _} = getpartymember(ctx, getcharid(ctx, 1))
      ctx = set_temp_var(ctx, :partymember, get_server_temp_var(ctx, "partymembercount", 0))

      cond do
        get_char_var(ctx, :QL_REVOL, 0) < 8 -> recruit(ctx)
        get_char_var(ctx, :QL_REVOL, 0) == 8 -> mission(ctx)
        true -> ctx
      end
    end
  end

  defp recruit(ctx) do
    members = get_temp_var(ctx, :partymember, 0)
    progress = get_char_var(ctx, :QL_REVOL, 0)

    cond do
      members == progress + 1 and members != 8 -> welcome_recruit(ctx)
      members == progress + 1 -> assign_mission(ctx)
      members < progress + 1 -> too_few(ctx)
      true -> too_many(ctx)
    end
  end

  defp welcome_recruit(ctx) do
    ctx =
      ctx
      |> set_char_var(:QL_REVOL, get_char_var(ctx, :QL_REVOL, 0) + 1)
      |> mes("[Sun Mao]")
      |> mes(
        "Oh, you brought a new comrade! Welcome. Please help your friend understand our intentions before joining us."
      )
      |> next()
      |> mes("[Sun Mao]")

    case get_char_var(ctx, :QL_REVOL, 0) do
      2 ->
        ctx
        |> mes(
          "Please bring another friend that both of you can trust. Remember, add one person at a time into your party."
        )
        |> next()
        |> mes("[Sun Mao]")
        |> mes(
          "Otherwise, other people may learn of what we are doing, and that will lead to trouble."
        )
        |> close()

      3 ->
        ctx
        |> mes(
          "The three of you may all move together for our cause. Please try to find another recruit to be your fourth member, invite him to your party and bring him to this place."
        )
        |> close()

      4 ->
        ctx
        |> mes(
          "Ah, now there are four of you. However, we must continue to strengthen our ranks at a cautious pace. Please go and find one new recruit, and only one, to add to your party."
        )
        |> close()

      5 ->
        ctx
        |> mes(
          "Now, there are five of you. Needless to say, we still require more manpower. Please go out and seek another new member for our cause. Remember, only add one more person to your party and return to me."
        )
        |> close()

      6 ->
        ctx
        |> mes(
          "There are now six of you. So far, so good. Please go forth and find just one more person to add to your party and bring him to me so that we may recruit him."
        )
        |> close()

      7 ->
        ctx
        |> mes(
          "Now, there are seven of you, but we still lack the manpower we need. Please go forth and seek out one, and only one, more person to add to your party and then return to me."
        )
        |> close()

      _ ->
        assign_mission(ctx)
    end
  end

  defp assign_mission(ctx) do
    ctx =
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "Great work, you've brought another new comrade! Welcome! Please explain our goals and the righteousness of our cause to our new friend so that he may fully join us."
      )
      |> next()

    if base_level(ctx) < 50 do
      ctx
      |> mes("[Sun Mao]")
      |> mes("It is almost time to take the action...")
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "I recognize your pledge to fight for us, but I fear that you are not yet ready for the task I have available for you."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "However, we still have time. Go out and train with the party members you have gathered to gain more experience."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Together, all of you will be able to train faster than if you were to go train alone. Come back when you feel that you are ready for this task."
      )
      |> close()
    else
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "At long last, there are eight of you. Now, I believe there is among manpower amongst you to carry out this mission. Please listen carefully."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "The martial arts organizations of Luoyang, as you may well know, have been divided between those that fight for justice, and those that serve evil purposes."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Recently, some of the evil organizations have conspired with corrupt government officials in the interest to expand their power."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "These corrupt government officials have been suspicious of our gunpowder research and arrested our comrade, ^3355FFHao Chenryu^000000, our gunpowder expert, under the pretext of investigation."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Without him, we cannot continue the gunpowder research, or produce the gunpowder we'll need for our movement. We must contact him so that he may make gunpowder for us."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Unfortunately, many of us cannot contact him, as our identities are known to the officials. However, since you are new recruits, as well as Midgardians, they will not know how you are."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Your mission will be to deliver these chemicals to our comrade Hao Chenryu who is held captive by the government."
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Since flammable chemicals are not allowed inside government offices, you must keep them well hidden. If the chemicals are equally divided among the eight of you, we might succeed!"
      )
      |> next()
      |> set_char_var(:QL_REVOL, 8)
      |> give_item(7068, 8)
      |> give_item(7096, 8)
      |> give_item(7004, 8)
      |> mes("[Sun Mao]")
      |> mes(
        "There you go. Now, divide these materials equally among the eight of you. The eight of you must fully cooperate with each other, or our plan will fail. Understood?"
      )
      |> close()
    end
  end

  defp too_few(ctx) do
    ctx = mes(ctx, "[Sun Mao]")

    case get_char_var(ctx, :QL_REVOL, 0) do
      1 ->
        ctx
        |> mes(
          "You made a party. Now, why don't you go recruit more followers? For now, just add one more person, lest we arouse the suspicion of our enemies."
        )
        |> close()

      2 ->
        ctx
        |> mes("Hmmm...")
        |> mes(
          "Having trouble finding a third person to add to your party? It's important that you find someone that is trustworthy. Be careful and don't get caught!"
        )
        |> close()

      3 ->
        ctx
        |> mes("Hmmm...")
        |> mes(
          "Having trouble finding a forth person to add to your party? I understand that it's important that you find someone you can trust. Be careful and don't get caught!"
        )
        |> close()

      4 ->
        ctx
        |> mes(
          "Having trouble finding a fifth person to add to your party? I understand that it's important that you find someone you can trust. Be careful and don't get caught!"
        )
        |> close()

      5 ->
        ctx
        |> mes(
          "Having trouble finding a six person to add to your party? It's important that you find someone that is trustworthy. Be careful and don't get caught!"
        )
        |> close()

      6 ->
        ctx
        |> mes(
          "Having trouble finding a seventh person to add to your party? It's important that you find someone that is trustworthy. Be careful and don't get caught!"
        )
        |> close()

      7 ->
        ctx
        |> mes("Hmmm...")
        |> mes(
          "Having trouble finding an eighth person to add to your party? It's important that you find someone that is trustworthy. Be careful and don't get caught!"
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp too_many(ctx) do
    ctx =
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "Oh no! You've brought more than one more person to join us! We can't do any recruiting now, it will bring unnecessary attention to our activities!"
      )
      |> next()
      |> mes("[Sun Mao]")

    case get_char_var(ctx, :QL_REVOL, 0) do
      1 ->
        ctx
        |> mes(
          "Please make sure that there is a total of two members in your party so that we can recruit your friend. I believe that will look natural."
        )
        |> close()

      2 ->
        ctx
        |> mes(
          "At this stage in our plan, we cannot afford any unnecessary attention to our activities! Please make sure that there is a total of three members in your party so that we can recruit your friend."
        )
        |> close()

      3 ->
        ctx
        |> mes(
          "Please make sure that there is a total of four members in your party so that we can recruit your friend. I believe that will look natural."
        )
        |> close()

      4 ->
        ctx
        |> mes(
          "Please make sure that there is a total of five members in your party so that we can recruit your friend. I believe that will look natural."
        )
        |> close()

      v when v in [5, 6] ->
        ctx
        |> mes(
          "By this time, you should know that you should only bring one more person at a time. You know that it is crucial that we do not attract any undue attention before we can take action!"
        )
        |> close()

      7 ->
        ctx
        |> mes(
          "At this stage in our plan, we cannot afford any unnecessary attention to our activities! Please make sure that there is a total of eight members in your party so that we can recruit your friend."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp mission(ctx) do
    cond do
      get_temp_var(ctx, :partymember, 0) != 8 -> missing_members(ctx)
      count_item(ctx, 7204) > 7 -> complete_mission(ctx)
      true -> mission_reminder(ctx)
    end
  end

  defp complete_mission(ctx) do
    ctx =
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "Welcome back! I see that the mission has been successfully accomplished! Great work, men!"
      )
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "Finally, we have a weapon to mete out severe retribution to our enemies, the corrupt government officials and the evil martial arts organizations! I appreciate your help, comrades."
      )
      |> next()

    ctx
    |> delitem(7204, count_item(ctx, 7204))
    |> set_char_var(:ch_make, 0)
    |> set_char_var(:QL_REVOL, 9)
    |> give_item(668, 8)
    |> mes("[Sun Mao]")
    |> mes(
      "Please take these funds and share them with your party members. I hope that all of you will lend your power to our cause once again."
    )
    |> next()
    |> mes("[Sun Mao]")
    |> mes("Once again, I thank you for your help. Now, go in safety.")
    |> close()
  end

  defp mission_reminder(ctx) do
    ctx
    |> mes("[Sun Mao]")
    |> mes(
      "Your mission is to take the materials I have given you and your party members, and to smuggle them to Hao Chenryu."
    )
    |> next()
    |> mes("[Sun Mao]")
    |> mes(
      "Hao Chenryu is currently held captive by corrupt members of the government. Remember to divide the materials equally among your party members so that the officials do find them."
    )
    |> close()
  end

  defp missing_members(ctx) do
    ctx
    |> mes("[Sun Mao]")
    |> mes("Huh, where are all your members? Come back to me with all of your recruits.")
    |> next()
    |> mes("[Sun Mao]")
    |> mes(
      "Remember that you move together with your comrades. There isn't a traitor amongst you, is there?"
    )
    |> close()
  end

  defp member(ctx) do
    if get_char_var(ctx, :ch_make, 0) == 1 do
      ctx
      |> set_char_var(:ch_make, 0)
      |> mes("[Sun Mao]")
      |> mes("Ah...")
      |> mes("You have")
      |> mes("returned!")
      |> mes("Ha ha ha ha!")
      |> next()
      |> mes("[Sun Mao]")
      |> mes(
        "I would like to commend you and your comrades for your excellent performance in the last mission. Come back anytime if you wish to be assigned to another task for our cause."
      )
      |> close()
    else
      ctx
      |> mes("[Sun Mao]")
      |> mes(
        "Remember that the authoritative center of the party is its leader. The party members must act as one in order to accomplish their goals."
      )
      |> close()
    end
  end
end
