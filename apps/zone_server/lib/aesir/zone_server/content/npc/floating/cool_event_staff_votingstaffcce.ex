defmodule Aesir.ZoneServer.Content.Npc.Floating.CoolEventStaffVotingstaffcce do
  @moduledoc """
  Cool Event Corp. voting staff in the eight major towns, who run the company's side of the
  Dungeon Teleport Service election.

  ## Behavior

  - Explains the election, records one vote per election and reports when no election is running.
  - Reports the dungeons Cool Event Corp. would offer, which follow the terms the company has won.
  - Sells the trial dungeon teleports while Cool Event Corp. holds the Dungeon Teleport Service,
    and reports that the service is unavailable otherwise.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Silent
    - Lupus
    - L0ne_W0lf
    - Euphy
    - Liam

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/dts_warper.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 153,
        y: 191,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#yuno"
      },
      %{
        map: "prontera",
        x: 147,
        y: 125,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#prt"
      },
      %{
        map: "moc_ruins",
        x: 97,
        y: 133,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#moc"
      },
      %{
        map: "geffen",
        x: 117,
        y: 37,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#gef"
      },
      %{
        map: "payon",
        x: 153,
        y: 182,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#pay"
      },
      %{
        map: "alberta",
        x: 114,
        y: 70,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#alb"
      },
      %{
        map: "aldebaran",
        x: 138,
        y: 102,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#alde"
      },
      %{
        map: "lighthalzen",
        x: 154,
        y: 60,
        dir: 6,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#lhz"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCleargarbage
  alias Aesir.ZoneServer.Script.Ctx

  @staff "[Cool Event Corp. Voting Staff]"
  @portrait "zonda_01"
  @color "^FF0000"
  @fee 4000

  @menu ["Reason for Election", "Cast a Vote", "Use Teleport Service", "Cancel"]

  @announced_dungeons %{
    0 => ["Byalan Dungeon, Level 3"],
    1 => ["Byalan Dungeon, Level 3", "Clock Tower, 3rd Floor"]
  }

  @all_dungeons [
    "Byalan Dungeon, Level 3",
    "Clock Tower, 3rd Floor",
    "Glast Heim Entrance"
  ]

  @destinations %{
    0 => [{"Byalan Dungeon, Level 3 -> 4,000 z", "iz_dun02", 234, 206}],
    1 => [
      {"Byalan Dungeon, Level 3 -> 4,000 z", "iz_dun02", 234, 206},
      {"Clock Tower, 3rd Floor -> 4,000 z", "c_tower3", 64, 143}
    ]
  }

  @all_destinations [
    {"Byalan Dungeon, Level 3 -> 4,000 z", "iz_dun02", 234, 206},
    {"Clock Tower, 3rd Floor -> 4,000 z", "c_tower3", 64, 143},
    {"Glast Heim Entrance -> 4,000 z", "glast_01", 368, 303}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} = FCleargarbage.call(ctx, [])

    {ctx, choice} =
      ctx
      |> cutin(@portrait, 2)
      |> mes(@staff)
      |> mes("Hello! Don't forget to make")
      |> mes("your voice be heard and make")
      |> mes("sure you vote in the elections")
      |> mes("between Cool Event Corp. and")
      |> mes("Kafra Corporation for control of the Dungeon Teleport Service!")
      |> next()
      |> select(@menu)

    ctx =
      case choice do
        1 -> explain_election(ctx)
        2 -> cast_vote(ctx)
        3 -> teleport_service(ctx)
        4 -> feedback(ctx)
        _other -> throw({:script_end, ctx})
      end

    ctx
    |> close()
    |> cutin(@portrait, 255)
  end

  defp explain_election(ctx) do
    ctx
    |> mes(@staff)
    |> mes("Cool Event Corp. has been")
    |> mes("planning to provide a new")
    |> mes("Dungeon Teleport Service to")
    |> mes("its customers, a service not")
    |> mes("already provided by the Kafra")
    |> mes("Corporation. However...")
    |> next()
    |> mes(@staff)
    |> mes("Kafra Corporation, which")
    |> mes("already monopolizes the")
    |> mes("public teleportation market,")
    |> mes("actually also had plans to")
    |> mes("provide a similar service.")
    |> next()
    |> mes(@staff)
    |> mes("Because of technological")
    |> mes("limitations, only one company")
    |> mes("can be chosen as the provider")
    |> mes("of this Dungeon Teleport Service. Hence, we will let the customers")
    |> mes("decide through these elections.")
    |> next()
    |> mes(@staff)
    |> mes("Multiple elections will be")
    |> mes("held so that our customers")
    |> mes("can test out the special services of each company for themselves.")
    |> mes("However, keep in mind that you must be eligible in order to vote.")
    |> next()
    |> mes(@staff)
    |> mes("For voter eligibility")
    |> mes("details, please visit our")
    |> mes("headquarters in the city of")
    |> mes("Lighthalzen located in the")
    |> mes("Schwarzwald Republic.")
    |> mes("Thank you for your time.")
  end

  defp cast_vote(ctx) do
    case get_server_var(ctx, "DTS_Result", 0) do
      0 -> open_vote(ctx, :first_election)
      3 -> open_vote(ctx, :runoff)
      _other -> no_election(ctx)
    end
  end

  defp open_vote(ctx, election) do
    if get_char_var(ctx, :lhz_vote, 0) <= get_server_var(ctx, "DTS_VoteCount", 0) do
      ctx
      |> vote_notice(election)
      |> vote_prompt()
    else
      already_voted(ctx, election)
    end
  end

  # The runoff election first reports why a new election is being held.
  defp vote_notice(ctx, :runoff) do
    ctx
    |> mes(@staff)
    |> mes("Unfortunately, there wasn't")
    |> mes("enough voter turnout in the")
    |> mes("last election, so we're holding")
    |> mes("another election to determine")
    |> mes("which company will provide the")
    |> mes("Dungeon Teleport Service.")
    |> next()
    |> vote_notice(:first_election)
  end

  defp vote_notice(ctx, :first_election) do
    ctx
    |> mes(@staff)
    |> mes("Cool Event Corp.,")
    |> mes("if chosen to provide the")
    |> mes("Dungeon Teleport Service,")
    |> mes("will teleport adventurers to")
    |> mes("the following dungeons...")
    |> next()
    |> mes(" ")
    |> mes(" ")
    |> announce_dungeons()
  end

  defp announce_dungeons(ctx) do
    terms = get_server_var(ctx, "DTS_JondaWins", 0)

    Enum.reduce(dungeons(terms), ctx, fn dungeon, ctx ->
      mes(ctx, "#{@color}#{dungeon}^000000")
    end)
  end

  defp vote_prompt(ctx) do
    {ctx, answer} =
      ctx
      |> next()
      |> mes(@staff)
      |> mes("If you are interested in")
      |> mes("these destinations, then")
      |> mes("it would be in your best")
      |> mes("interest to vote for us.")
      |> mes("Would you like to vote")
      |> mes("for Cool Event Corp.?")
      |> next()
      |> select(["No", "Yes"])

    case answer do
      1 -> vote_declined(ctx)
      2 -> vote_cast(ctx)
      _other -> throw({:script_end, ctx})
    end
  end

  defp vote_declined(ctx) do
    ctx
    |> mes(@staff)
    |> mes("Ah, I see... Well, if you")
    |> mes("happen to change your mind,")
    |> mes("feel free to come back and")
    |> mes("cast your vote for Cool Event")
    |> mes("Corp, alright? Have a nice day~")
  end

  defp vote_cast(ctx) do
    ctx = set_char_var(ctx, :lhz_vote, get_server_var(ctx, "DTS_VoteCount", 0) + 1)

    ctx
    |> set_server_var("DTS_JondaVotes", get_server_var(ctx, "DTS_JondaVotes", 0) + 1)
    |> mes(@staff)
    |> mes("Thank you for your vote!")
    |> mes("It's customers like you who")
    |> mes("ensure the success and great")
    |> mes("service that you have come to")
    |> mes("expect from Cool Event Corp.")
    |> mes("Thank you and have a nice day~")
  end

  defp already_voted(ctx, :first_election) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but you've")
    |> mes("already cast your vote")
    |> mes("in this election. However,")
    |> mes("please don't let that stop you")
    |> mes("from voting for Cool Event")
    |> mes("Corp. in the next election~")
  end

  defp already_voted(ctx, :runoff) do
    ctx
    |> mes(@staff)
    |> mes("Unfortunately, there wasn't")
    |> mes("enough voter turnout in the")
    |> mes("last election, so we're holding")
    |> mes("another election to determine")
    |> mes("which company will provide the")
    |> mes("Dungeon Teleport Service.")
    |> next()
    |> mes(@staff)
    |> mes("We appreciate that")
    |> mes("you've already participated")
    |> mes("in this second election by")
    |> mes("casting your vote. Thank")
    |> mes("you for your support~")
  end

  defp no_election(ctx) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but an election is")
    |> mes("not currently being held at this time. Please come and cast your")
    |> mes("vote at the next election to decide which company will provide the")
    |> mes("Dungeon Teleport Service.")
  end

  defp teleport_service(ctx) do
    case get_server_var(ctx, "DTS_Result", 0) do
      1 -> offer_teleport(ctx)
      2 -> service_lost(ctx)
      _other -> service_suspended(ctx)
    end
  end

  defp offer_teleport(ctx) do
    terms = get_server_var(ctx, "DTS_JondaWins", 0)

    # The reference shows the fee notice before every destination menu and repeats it once more
    # on the three-destination one.
    ctx = fee_notice(ctx)
    ctx = if terms > 1, do: fee_notice(ctx), else: ctx

    targets = destinations(terms)
    {ctx, choice} = select(ctx, Enum.map(targets, &elem(&1, 0)) ++ ["Cancel"])

    case Enum.at(targets, choice - 1) do
      nil when choice == length(targets) + 1 -> service_feedback(ctx)
      nil -> throw({:script_end, ctx})
      target -> travel(ctx, target)
    end
  end

  defp fee_notice(ctx) do
    ctx
    |> mes(@staff)
    |> mes("Please remember that we")
    |> mes("cannot accept Free Warp Tickets")
    |> mes("or award Special Reserve Points")
    |> mes("for this service. Now, please")
    |> mes("choose your destination.")
    |> next()
  end

  defp travel(ctx, {_label, map, x, y}) do
    if zeny(ctx) >= @fee do
      ctx =
        ctx
        |> pay_zeny(@fee)
        |> cutin(@portrait, 255)
        |> warp(map, x, y)

      throw({:script_end, ctx})
    else
      ctx
      |> mes(@staff)
      |> mes("I'm sorry, but you do")
      |> mes("not have enough zeny to")
      |> mes("teleport to this destination.")
      |> mes("The teleport fee is 4,000 zeny.")
    end
  end

  defp service_feedback(ctx) do
    ctx
    |> mes(@staff)
    |> mes("Always be assured that")
    |> mes("Cool Event Corp. will do")
    |> mes("everything in its power to")
    |> mes("ensure the satisfaction of")
    |> mes("its customers, young and old")
    |> mes("and big and small. Thank you~")
  end

  defp service_lost(ctx) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but Cool Event")
    |> mes("Corp. does not currently offer")
    |> mes("the Dungeon Teleport Service")
    |> mes("due to the results of the last")
    |> mes("election. Please vote for us")
    |> mes("next time, alright? Good day~")
  end

  defp service_suspended(ctx) do
    ctx
    |> mes(@staff)
    |> mes("I'm sorry, but the")
    |> mes("Dungeon Teleport Service is")
    |> mes("unavailable during elections")
    |> mes("and will be reactivated after the election results are announced.")
    |> mes("Thank you and have a nice day.")
  end

  defp feedback(ctx) do
    ctx
    |> mes(@staff)
    |> mes("Cool Event Corp. is always")
    |> mes("working to make sure that")
    |> mes("not only are our customers")
    |> mes("satisfied, but that we also")
    |> mes("exceed your utmost standards.")
    |> mes("Thank you and have a good day.")
  end

  defp dungeons(terms) when terms in [0, 1], do: Map.fetch!(@announced_dungeons, terms)
  defp dungeons(_terms), do: @all_dungeons

  defp destinations(terms) when terms in [0, 1], do: Map.fetch!(@destinations, terms)
  defp destinations(_terms), do: @all_destinations
end
