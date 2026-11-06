defmodule Aesir.ZoneServer.Content.Npc.Functions.FVotekafra do
  @moduledoc """
  Runs the Kafra side of the Dungeon Teleport Service election.

  ## Behavior

  The staff member explains the election, tallies a vote, or sells one of the trial-period
  teleports, depending on the menu choice and on the election state the server variables hold.
  A vote is only accepted once per election, bumps both the personal marker and the Kafra tally,
  and the dungeon lists the staff quotes follow the number of dungeons the Kafra side won. The
  teleport menu is limited to the dungeons the Kafra side provides, costs 4000 zeny per trip, and
  the fee message names the chosen dungeon. Any outcome other than an election in progress gets
  its own notice.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - L0ne_W0lf
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/dts_warper.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Content.Npc.Functions.FCleargarbage
  alias Aesir.ZoneServer.Script.Ctx

  @staff "[Kafra Voting Staff]"
  @fee 4000

  @vote_dungeons %{
    0 => ["^FF0000Toy Factory, Level 2^000000"],
    1 => [
      "^FF0000Toy Factory, Level 2^000000",
      "^FF0000Al De Baran Clock Tower, Level 3 ^000000"
    ],
    :many => [
      "^FF0000Toy Factory, Level 2^000000",
      "^FF0000Al De Baran Clock Tower, Level 3 Lava Dungeon, Level 2^000000"
    ]
  }

  @destinations %{
    0 => [
      %{
        label: "Toy Factory, Level 2 -> 4,000 z",
        name: "Toy Factory",
        map: "xmas_dun02",
        x: 130,
        y: 123,
        cutin: {"", 255, :before}
      }
    ],
    1 => [
      %{
        label: "Toy Factory, Level 2 -> 4,000 z",
        name: "Toy Factory",
        map: "xmas_dun02",
        x: 130,
        y: 123,
        cutin: {"kafra_09", 255, :after}
      },
      %{
        label: "Clock Tower, Level 3 -> 4,000 z",
        name: "Clock Tower",
        map: "alde_dun03",
        x: 265,
        y: 22,
        cutin: {"kafra_09", 255, :after}
      }
    ],
    :many => [
      %{
        label: "Toy Factory, Level 2 -> 4,000 z",
        name: "Toy Factory",
        map: "xmas_dun02",
        x: 130,
        y: 123,
        cutin: {"kafra_09", 255, :after}
      },
      %{
        label: "Clock Tower, Level 3 -> 4,000 z",
        name: "Clock Tower",
        map: "alde_dun03",
        x: 265,
        y: 22,
        cutin: {"kafra_09", 255, :after}
      },
      %{
        label: "Lava Dungeon, Level 2 -> 4,000 z",
        name: "Lava Dungeon",
        map: "mag_dun02",
        x: 47,
        y: 40,
        cutin: {"kafra_09", 255, :after}
      }
    ]
  }

  @doc """
  Callable rAthena global function `F_VoteKafra(portrait)`; throws `{:script_end, ctx}` after the
  chosen service.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    {ctx, _cleared} = FCleargarbage.call(ctx, [])

    {ctx, choice} =
      ctx
      |> portrait(Enum.at(args, 0, 0))
      |> mes(@staff)
      |> mes("Greetings, adventurer.")
      |> mes("As you may be aware, we")
      |> mes("are holding an election to")
      |> mes("determine which company will")
      |> mes("provide the Dungeon Teleport")
      |> mes("Service. How may I help you?")
      |> next()
      |> select(["Reason for Election", "Cast a Vote", "Use Teleport Service", "Cancel"])

    ctx =
      case choice do
        1 -> election_reason(ctx)
        2 -> vote(ctx)
        3 -> teleport_service(ctx)
        4 -> corporate_blurb(ctx)
        _other -> halt(ctx)
      end

    halt(ctx |> close() |> cutin("", 255))
  end

  defp portrait(ctx, staff_id) when staff_id in 1..9, do: cutin(ctx, "kafra_0#{staff_id}", 2)
  defp portrait(ctx, _staff_id), do: ctx

  defp election_reason(ctx) do
    ctx
    |> mes(@staff)
    |> mes("Cool Event Corp and the")
    |> mes("Kafra Corporation have both")
    |> mes("been planning to provide a")
    |> mes("Teleport Service to dungeons.")
    |> next()
    |> mes(@staff)
    |> mes("But due to technological")
    |> mes("limitations, only one company")
    |> mes("can serve as provider for this")
    |> mes("Dungeon Teleport Service at a")
    |> mes("time. There, both companies have agreed to hold special elections.")
    |> next()
    |> mes(@staff)
    |> mes("Each company has its own")
    |> mes("policies and guarantees in")
    |> mes("regards to the Dungeon Teleport Service, and in this election, the")
    |> mes("customers will ultimately decide and choose what's best for them.")
    |> next()
    |> mes(@staff)
    |> mes("For now, the Dungeon")
    |> mes("Teleport Service will be")
    |> mes("provided in a series of trial periods. This way, customers can")
    |> mes("see the benefits of both companies before making the final decision.")
    |> next()
    |> mes(@staff)
    |> mes("If you are qualified,")
    |> mes("please vote in each election")
    |> mes("to decide which company will")
    |> mes("provide the Dungeon Teleport")
    |> mes("Service for the next trial period. Thank you for your support~")
  end

  defp vote(ctx) do
    case get_server_var(ctx, "DTS_Result", 0) do
      0 -> cast_or_refuse(ctx, :first)
      3 -> cast_or_refuse(ctx, :rerun)
      _other -> no_election(ctx)
    end
  end

  defp cast_or_refuse(ctx, round) do
    if get_char_var(ctx, :lhz_vote, 0) <= get_server_var(ctx, "DTS_VoteCount", 0) do
      ctx |> vote_pages(round) |> vote_question(round)
    else
      already_voted(ctx, round)
    end
  end

  defp vote_pages(ctx, :first) do
    ctx
    |> mes(@staff)
    |> mes("We, the Kafra Corporation,")
    |> mes("are planning to provide the")
    |> mes("Dungeon Teleport Service")
    |> mes("to the following dungeons...")
    |> next()
    |> dungeon_lists()
  end

  defp vote_pages(ctx, :rerun) do
    ctx
    |> mes(@staff)
    |> mes("After totalling the number of")
    |> mes("votes from the last election,")
    |> mes("we have concluded that the")
    |> mes("minimum voter participation")
    |> mes("condition was not satisfied.")
    |> next()
    |> mes(@staff)
    |> mes("Therefore, another election to")
    |> mes("determine which company will")
    |> mes("provide the Dungeon Teleport")
    |> mes("Service will be held. The Kafra")
    |> mes("Corporation will teleport to")
    |> mes("the following dungeons...")
    |> next()
    |> dungeon_lists()
  end

  defp dungeon_lists(ctx) do
    won = get_server_var(ctx, "DTS_KafraWins", 0)

    ctx
    |> mes(" ")
    |> mes(" ")
    |> then(fn ctx -> Enum.reduce(won_dungeons(won), ctx, &mes(&2, &1)) end)
    |> next()
  end

  defp vote_question(ctx, round) do
    {ctx, choice} = ctx |> vote_prompt(round) |> select(["No", "Yes"])

    case choice do
      1 -> vote_declined(ctx)
      2 -> vote_recorded(ctx)
      _other -> halt(ctx)
    end
  end

  defp vote_prompt(ctx, :first) do
    ctx
    |> mes(@staff)
    |> mes("If you are interested in")
    |> mes("a Teleport Service to this")
    |> mes("area, then please vote for")
    |> mes("us. Would you like to vote")
    |> mes("for the Kafra Corporation?")
    |> next()
  end

  defp vote_prompt(ctx, :rerun) do
    ctx
    |> mes(@staff)
    |> mes("If you are interested in")
    |> mes("a Teleport Service to these")
    |> mes("areas, then please vote for")
    |> mes("us. Would you like to vote")
    |> mes("for the Kafra Corporation?")
    |> next()
  end

  defp vote_declined(ctx) do
    ctx
    |> mes(@staff)
    |> mes("I understand. But if you")
    |> mes("happen to change your mind,")
    |> mes("you are welcome to come back")
    |> mes("at any time. Thank you and")
    |> mes("have a good day, adventurer.")
  end

  defp vote_recorded(ctx) do
    ctx
    |> set_char_var(:lhz_vote, get_server_var(ctx, "DTS_VoteCount", 0) + 1)
    |> set_server_var("DTS_KafraVotes", get_server_var(ctx, "DTS_KafraVotes", 0) + 1)
    |> mes(@staff)
    |> mes("Thanks for your vote!")
    |> mes("We'll continue to do our best")
    |> mes("to provide the highest quality")
    |> mes("service to our customers. Have")
    |> mes("a good day and remember that the Kafra service is on your side~")
  end

  defp already_voted(ctx, :first) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but you've ")
    |> mes("already participated in")
    |> mes("this election. When the next")
    |> mes("election comes, you will be")
    |> mes("able to vote once again.")
    |> mes("Thank you for your support~")
  end

  defp already_voted(ctx, :rerun) do
    ctx
    |> mes(@staff)
    |> mes("After totalling the number of")
    |> mes("votes from the last election,")
    |> mes("we have concluded that the")
    |> mes("minimum voter participation")
    |> mes("condition was not satisfied.")
    |> next()
    |> mes(@staff)
    |> mes("Therefore, another election to")
    |> mes("determine which company will")
    |> mes("provide the Dungeon Teleport")
    |> mes("Service will be held. However,")
    |> mes("since you've already voted, you cannot vote again in this election.")
    |> next()
    |> mes(@staff)
    |> mes("Your participation in these")
    |> mes("elections is much appreciated,")
    |> mes("and we encourage you to vote")
    |> mes("again during the next election.")
    |> mes("Thank you and have a nice day~")
  end

  defp no_election(ctx) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but there are")
    |> mes("no elections taking place at")
    |> mes("this time. When the polls are")
    |> mes("open, we encourage you to take")
    |> mes("part and voice your opinions.")
    |> mes("Thank you for your support~")
  end

  defp teleport_service(ctx) do
    case get_server_var(ctx, "DTS_Result", 0) do
      2 -> dungeon_menu(ctx)
      1 -> other_provider(ctx)
      _other -> service_inactive(ctx)
    end
  end

  defp other_provider(ctx) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but because of")
    |> mes("the results from the most")
    |> mes("recent election, Cool Event")
    |> mes("Corp. is currently handling")
    |> mes("the Dungeon Teleport Service. We apologize for the inconvenience.")
  end

  defp service_inactive(ctx) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but the")
    |> mes("Dungeon Teleport Service")
    |> mes("is not active during the voting")
    |> mes("period. Once the election is")
    |> mes("over, the Dungeon Teleport")
    |> mes("Service will become available.")
  end

  defp dungeon_menu(ctx) do
    ctx =
      ctx
      |> mes(@staff)
      |> mes("Thank you for choosing the")
      |> mes("Dungeon Teleport Service.")
      |> mes("Please keep in mind that the")
      |> mes("Free Warp Tickets and Kafra")
      |> mes("Special Reserve Points do not")
      |> mes("apply in this special service.")
      |> next()

    offered = destinations(get_server_var(ctx, "DTS_KafraWins", 0))
    {ctx, choice} = select(ctx, Enum.map(offered, & &1.label) ++ ["Cancel"])

    cond do
      choice in 1..length(offered) -> travel(ctx, Enum.at(offered, choice - 1))
      choice == length(offered) + 1 -> corporate_blurb(ctx)
      true -> halt(ctx)
    end
  end

  defp travel(ctx, %{cutin: {image, colour, :before}} = destination) do
    if zeny(ctx) >= @fee do
      ctx
      |> cutin(image, colour)
      |> pay_zeny(@fee)
      |> warp(destination.map, destination.x, destination.y)
      |> halt()
    else
      short_of_funds(ctx, destination.name)
    end
  end

  defp travel(ctx, %{cutin: {image, colour, :after}} = destination) do
    if zeny(ctx) >= @fee do
      ctx
      |> pay_zeny(@fee)
      |> cutin(image, colour)
      |> warp(destination.map, destination.x, destination.y)
      |> halt()
    else
      short_of_funds(ctx, destination.name)
    end
  end

  defp short_of_funds(ctx, dungeon) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but you don't")
    |> mes("have enough money to pay")
    |> mes("the 4,000 zeny fee to teleport")
    |> mes("to the #{dungeon}. Please")
    |> mes("check your funds again.")
  end

  defp corporate_blurb(ctx) do
    ctx
    |> mes(@staff)
    |> mes("We, here at Kafra Corporation,")
    |> mes(
      "are always endeavoring to provide you with the best services. We hope that we meet your adventuring needs and standards of excellence."
    )
  end

  defp won_dungeons(0), do: @vote_dungeons[0]
  defp won_dungeons(1), do: @vote_dungeons[1]
  defp won_dungeons(_more), do: @vote_dungeons[:many]

  defp destinations(0), do: @destinations[0]
  defp destinations(1), do: @destinations[1]
  defp destinations(_more), do: @destinations[:many]

  defp halt(ctx), do: throw({:script_end, ctx})
end
