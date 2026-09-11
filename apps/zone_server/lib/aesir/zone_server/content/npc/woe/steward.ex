defmodule Aesir.ZoneServer.Content.Npc.Woe.Steward do
  @moduledoc """
  Castle steward: reports one FE castle's economy briefing to its owning
  guild's master and lets them invest in commercial growth or castle
  defenses.

  One placement per FE castle map, sharing one `on_talk/1` that resolves the
  castle at the player's current map and reads castle state and ownership
  entirely through `Aesir.ZoneServer.Script.Dsl` castle ops.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{
        map: "aldeg_cas01",
        x: 218,
        y: 175,
        dir: 0,
        sprite: 55,
        name: "Alfredo",
        unique_name: "Steward#aldeg_cas01"
      },
      %{
        map: "aldeg_cas02",
        x: 78,
        y: 74,
        dir: 0,
        sprite: 55,
        name: "Chenchenlie",
        unique_name: "Steward#aldeg_cas02"
      },
      %{
        map: "aldeg_cas03",
        x: 110,
        y: 118,
        dir: 0,
        sprite: 55,
        name: "Nahzarf",
        unique_name: "Steward#aldeg_cas03"
      },
      %{
        map: "aldeg_cas04",
        x: 67,
        y: 116,
        dir: 0,
        sprite: 55,
        name: "Brymhensen",
        unique_name: "Steward#aldeg_cas04"
      },
      %{
        map: "aldeg_cas05",
        x: 51,
        y: 179,
        dir: 0,
        sprite: 55,
        name: "Esmarehk",
        unique_name: "Steward#aldeg_cas05"
      },
      %{
        map: "gefg_cas01",
        x: 40,
        y: 48,
        dir: 5,
        sprite: 55,
        name: "Gnahcher",
        unique_name: "Steward#gefg_cas01"
      },
      %{
        map: "gefg_cas02",
        x: 12,
        y: 66,
        dir: 5,
        sprite: 55,
        name: "Esmarehk",
        unique_name: "Steward#gefg_cas02"
      },
      %{
        map: "gefg_cas03",
        x: 106,
        y: 23,
        dir: 5,
        sprite: 55,
        name: "Jyang",
        unique_name: "Steward#gefg_cas03"
      },
      %{
        map: "gefg_cas04",
        x: 73,
        y: 46,
        dir: 3,
        sprite: 55,
        name: "Kellvahni",
        unique_name: "Steward#gefg_cas04"
      },
      %{
        map: "gefg_cas05",
        x: 70,
        y: 52,
        dir: 3,
        sprite: 55,
        name: "Byohre",
        unique_name: "Steward#gefg_cas05"
      },
      %{
        map: "payg_cas01",
        x: 120,
        y: 58,
        dir: 4,
        sprite: 55,
        name: "Kurunnadi",
        unique_name: "Steward#payg_cas01"
      },
      %{
        map: "payg_cas02",
        x: 22,
        y: 260,
        dir: 7,
        sprite: 55,
        name: "Cherieos",
        unique_name: "Steward#payg_cas02"
      },
      %{
        map: "payg_cas03",
        x: 50,
        y: 261,
        dir: 3,
        sprite: 55,
        name: "Gheriot",
        unique_name: "Steward#payg_cas03"
      },
      %{
        map: "payg_cas04",
        x: 38,
        y: 284,
        dir: 3,
        sprite: 55,
        name: "DJ",
        unique_name: "Steward#payg_cas04"
      },
      %{
        map: "payg_cas05",
        x: 277,
        y: 249,
        dir: 3,
        sprite: 55,
        name: "Nahzarf",
        unique_name: "Steward#payg_cas05"
      },
      %{
        map: "prtg_cas01",
        x: 112,
        y: 181,
        dir: 0,
        sprite: 55,
        name: "Ahvray",
        unique_name: "Steward#prtg_cas01"
      },
      %{
        map: "prtg_cas02",
        x: 94,
        y: 61,
        dir: 4,
        sprite: 55,
        name: "Roy",
        unique_name: "Steward#prtg_cas02"
      },
      %{
        map: "prtg_cas03",
        x: 51,
        y: 100,
        dir: 4,
        sprite: 55,
        name: "Sttick",
        unique_name: "Steward#prtg_cas03"
      },
      %{
        map: "prtg_cas04",
        x: 259,
        y: 265,
        dir: 4,
        sprite: 55,
        name: "Van Dreth",
        unique_name: "Steward#prtg_cas04"
      },
      %{
        map: "prtg_cas05",
        x: 36,
        y: 37,
        dir: 4,
        sprite: 55,
        name: "Raynor",
        unique_name: "Steward#prtg_cas05"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case castle_at(ctx) do
      nil -> close(ctx)
      castle_id -> handle_castle(ctx, castle_id)
    end
  end

  defp handle_castle(ctx, castle_id) do
    case castle_owner(ctx, castle_id) do
      nil -> refuse_no_master(ctx)
      owner -> handle_owned_castle(ctx, castle_id, owner)
    end
  end

  defp handle_owned_castle(ctx, castle_id, owner) do
    if getcharid(ctx, 2) == owner and is_guild_leader(ctx, owner) do
      greet_master(ctx, castle_id)
    else
      refuse_not_master(ctx)
    end
  end

  defp refuse_no_master(ctx) do
    ctx
    |> say([
      "I have been waiting for a master to fulfill my destiny.",
      "Brave soul... fate will guide you towards your future..."
    ])
    |> close()
  end

  defp refuse_not_master(ctx) do
    ctx
    |> say([
      "No matter how much you pester me, I'll still follow my master. " <>
        "Where are the Guardians?! Send these ruffians away right now!"
    ])
    |> close()
  end

  defp greet_master(ctx, castle_id) do
    {ctx, choice} =
      ctx
      |> say([
        "Welcome. My honorable master, ^ff0000#{char_name(ctx, 0)}^000000...",
        "Your humble servant, #{strnpcinfo(ctx, 1)}, is here to serve you."
      ])
      |> next()
      |> select(["Castle briefing", "Invest in commercial growth", "Invest in Castle Defenses"])

    handle_menu(ctx, castle_id, choice)
  end

  defp handle_menu(ctx, castle_id, 1), do: briefing(ctx, castle_id)
  defp handle_menu(ctx, castle_id, 2), do: invest_economy(ctx, castle_id)
  defp handle_menu(ctx, castle_id, 3), do: invest_defense(ctx, castle_id)
  defp handle_menu(ctx, _castle_id, _choice), do: close(ctx)

  defp briefing(ctx, castle_id) do
    state = castle_economy(ctx, castle_id)

    ctx
    |> say([
      "I will report the Castle briefing, Master.",
      " ",
      "^0000ffNow, the commercial growth level is #{state.economy}."
    ])
    |> investment_note(
      state.invested_economy,
      "You invested #{state.invested_economy} times in past 1 day."
    )
    |> mes("Now, the Castle Defense level is #{state.defense}.^000000")
    |> investment_note(
      state.invested_defense,
      "^0000ff- You invested #{state.invested_defense} times in past 1 day.^000000"
    )
    |> mes(" ")
    |> mes("That's all I have to report, Master.")
    |> close()
  end

  defp investment_note(ctx, 0, _line), do: ctx
  defp investment_note(ctx, _count, line), do: mes(ctx, line)

  defp invest_economy(ctx, castle_id) do
    invest_flow(ctx, castle_id, :economy,
      pitch: [
        "If you invest in commercial growth, the quantity of goods made by the guild will " <>
          "increase. Therefore, if you consider our future, investments will be a necessity.",
        " ",
        "Initially, you are able to invest just once but if you pay more money, you will be " <>
          "able to invest twice."
      ],
      maxed:
        "^ff0000The commercial growth level of our Castle is at it's highest, 100%. No more " <>
          "investments are needed. Just as I have expected from a great economist like you, " <>
          "Master.^000000",
      daily_limit:
        "^ff0000You have already invested twice today. You cannot invest any more.^000000 " <>
          "I expect riches of the guild to grow at a high rate.",
      confirm_label: "Invest in commercial growth",
      success:
        "We finished the investment safely. I expect that our growth level will be increased by tomorrow."
    )
  end

  defp invest_defense(ctx, castle_id) do
    invest_flow(ctx, castle_id, :defense,
      pitch: [
        "If you raise Castle Defenses, the durability of Guardians and the Emperium will " <>
          "increase. Therefore, if you consider our coming battles, some investment in this " <>
          "area will be required.",
        " ",
        "Originally you can invest just once but if you pay more money, you can invest twice."
      ],
      maxed:
        "^ff0000But the Castle Defense level of our Castle is at it's highest, 100%. No more " <>
          "investments are needed. Just as I have expected from a great strategist like you, " <>
          "Master.^000000",
      daily_limit:
        "^ff0000You have already invested twice today. You cannot invest any more.^000000 " <>
          "I expect the Defenses of the guild to grow at a high rate.",
      confirm_label: "Invest in Castle Defenses.",
      success:
        "We finished the investment safely. I expect that our Castle Defense level will be increased by tomorrow."
    )
  end

  defp invest_flow(ctx, castle_id, kind, copy) do
    state = castle_economy(ctx, castle_id)
    level = Map.fetch!(state, kind)
    invested = Map.fetch!(state, invested_field(kind))
    cost = castle_invest_cost(ctx, castle_id, kind)

    ctx = say(ctx, Keyword.fetch!(copy, :pitch) ++ [" "])

    cond do
      level >= 100 ->
        ctx |> mes(Keyword.fetch!(copy, :maxed)) |> close()

      invested >= 2 ->
        ctx |> mes(Keyword.fetch!(copy, :daily_limit)) |> close()

      true ->
        ctx
        |> mes(cost_prompt(invested, cost))
        |> next()
        |> select([Keyword.fetch!(copy, :confirm_label), "Cancel"])
        |> confirm_investment(castle_id, kind, cost, Keyword.fetch!(copy, :success))
    end
  end

  defp cost_prompt(0, cost),
    do: "The current investment amount required is ^ff0000#{cost}^000000 zeny. Will you invest?"

  defp cost_prompt(_invested, cost),
    do:
      "You've invested once today... if you wish to invest once more, ^ff0000#{cost}^000000 " <>
        "more zeny will be needed."

  defp confirm_investment({ctx, 1}, castle_id, kind, cost, success_message) do
    if zeny(ctx) < cost do
      ctx
      |> say([
        "I'm sorry but there is not enough zeny to invest. You will have to try again when " <>
          "you have the funds, Master."
      ])
      |> close()
    else
      ctx
      |> pay_zeny(cost)
      |> castle_invest(castle_id, kind)
      |> say([success_message])
      |> close()
    end
  end

  defp confirm_investment({ctx, _cancel}, _castle_id, _kind, _cost, _success_message) do
    ctx
    |> say(["I'll do as you bid, my master... There is no hurry. We will do our best."])
    |> close()
  end

  defp invested_field(:economy), do: :invested_economy
  defp invested_field(:defense), do: :invested_defense

  defp say(ctx, lines), do: Enum.reduce(["[#{strnpcinfo(ctx, 1)}]" | lines], ctx, &mes(&2, &1))
end
