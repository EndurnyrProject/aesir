defmodule Aesir.ZoneServer.Content.Npc.Woe.Steward do
  @moduledoc """
  Castle steward: reports one FE castle's economy briefing to its owning
  guild's master, lets them invest in commercial growth or castle defenses,
  and hires guardians into the castle's empty slots.

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

  @master_rooms %{
    "aldeg_cas01" => {113, 223},
    "aldeg_cas02" => {134, 225},
    "aldeg_cas03" => {229, 267},
    "aldeg_cas04" => {83, 17},
    "aldeg_cas05" => {64, 8},
    "gefg_cas01" => {152, 117},
    "gefg_cas02" => {145, 115},
    "gefg_cas03" => {275, 289},
    "gefg_cas04" => {116, 123},
    "gefg_cas05" => {149, 106},
    "payg_cas01" => {295, 8},
    "payg_cas02" => {141, 149},
    "payg_cas03" => {163, 167},
    "payg_cas04" => {151, 47},
    "payg_cas05" => {153, 137},
    "prtg_cas01" => {15, 209},
    "prtg_cas02" => {207, 229},
    "prtg_cas03" => {190, 130},
    "prtg_cas04" => {275, 160},
    "prtg_cas05" => {281, 176}
  }

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
      |> select([
        "Castle briefing",
        "Invest in commercial growth",
        "Invest in Castle Defenses",
        "Summon Guardian",
        "Hire / Fire a Kafra Employee",
        "Go into Master's room"
      ])

    handle_menu(ctx, castle_id, choice)
  end

  defp handle_menu(ctx, castle_id, 1), do: briefing(ctx, castle_id)
  defp handle_menu(ctx, castle_id, 2), do: invest_economy(ctx, castle_id)
  defp handle_menu(ctx, castle_id, 3), do: invest_defense(ctx, castle_id)
  defp handle_menu(ctx, castle_id, 4), do: summon_guardian(ctx, castle_id)
  defp handle_menu(ctx, castle_id, 5), do: kafra_service(ctx, castle_id)
  defp handle_menu(ctx, castle_id, 6), do: master_room(ctx, castle_id)
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

  defp confirm_investment({ctx, _cancel}, _castle_id, _kind, _cost, _success_message),
    do: dismiss(ctx)

  defp invested_field(:economy), do: :invested_economy
  defp invested_field(:defense), do: :invested_defense

  defp summon_guardian(ctx, castle_id) do
    slots = castle_guardians(ctx, castle_id)

    {ctx, choice} =
      ctx
      |> say([
        "Will you summon a Guardian? It'll be a protector to defend us loyally.",
        "Please select a guardian to defend us."
      ])
      |> next()
      |> select(Enum.map(slots, &guardian_label/1) ++ ["Cancel"])

    handle_guardian_select(ctx, castle_id, choice)
  end

  defp guardian_label(%{type: type, hired?: hired?}) do
    guardian_type_label(type) <> if hired?, do: " (Summoned)", else: ""
  end

  defp guardian_type_label(:soldier), do: "Guardian Soldier"
  defp guardian_type_label(:archer), do: "Guardian Archer"
  defp guardian_type_label(:knight), do: "Guardian Knight"

  defp handle_guardian_select(ctx, castle_id, choice) when choice in 1..8,
    do: confirm_guardian(ctx, castle_id, choice - 1)

  defp handle_guardian_select(ctx, _castle_id, _cancel), do: dismiss(ctx)

  defp confirm_guardian(ctx, castle_id, slot) do
    {ctx, choice} =
      ctx
      |> say([
        "Will you summon the chosen guardian? 10,000 zeny are required to summon a Guardian."
      ])
      |> select(["Summon", "Cancel"])

    case choice do
      1 -> resolve_guardian_hire(ctx, castle_id, slot)
      _ -> dismiss(ctx)
    end
  end

  defp resolve_guardian_hire(ctx, castle_id, slot) do
    case castle_guardian_hire_check(ctx, castle_id, slot) do
      {:error, :research_required} ->
        ctx
        |> say([
          "Master, we have not the resources to Summon the Guardian. If you want to " <>
            "accumulate them, you have to learn the Guild skill. We failed to summon the " <>
            "Guardian."
        ])
        |> close()

      {:error, :already_hired} ->
        ctx
        |> say(["Master, you already have summoned that Guardian. We cannot summon another."])
        |> close()

      {:error, _reason} ->
        close(ctx)

      :ok ->
        hire_guardian(ctx, castle_id, slot)
    end
  end

  defp hire_guardian(ctx, castle_id, slot) do
    if zeny(ctx) < 10_000 do
      ctx
      |> say([
        "Well... I'm sorry but we don't have funds to summon the Guardian. We failed to " <>
          "summon the Guardian."
      ])
      |> close()
    else
      ctx
      |> pay_zeny(10_000)
      |> castle_hire_guardian(castle_id, slot)
      |> say([
        "We completed the summoning of the Guardian. Our defenses are now increased with " <>
          "it in place."
      ])
      |> close()
    end
  end

  defp dismiss(ctx) do
    ctx
    |> say(["I'll do as you bid, my master... There is no hurry. We will do our best."])
    |> close()
  end

  defp kafra_service(ctx, castle_id) do
    if castle_kafra_hired?(ctx, castle_id) do
      offer_fire_kafra(ctx, castle_id)
    else
      offer_hire_kafra(ctx, castle_id)
    end
  end

  defp offer_fire_kafra(ctx, castle_id) do
    {ctx, choice} =
      ctx
      |> say([
        "We are currently hiring a Kafra Employee... Do you want to fire the Kafra Employee?"
      ])
      |> next()
      |> select(["Fire", "Cancel"])

    case choice do
      1 -> confirm_fire_kafra(ctx, castle_id)
      _ -> keep_kafra(ctx)
    end
  end

  defp confirm_fire_kafra(ctx, castle_id) do
    {ctx, choice} =
      ctx
      |> cutin("kafra_01", 2)
      |> kafra_say([
        "I worked so hard... How can you do that, Master?... Please... Please reconsider... " <>
          "Check it again, Master... Please..."
      ])
      |> next()
      |> select(["Fire", "Cancel"])

    case choice do
      1 -> fire_kafra(ctx, castle_id)
      _ -> keep_kafra_after_plea(ctx)
    end
  end

  defp fire_kafra(ctx, castle_id) do
    ctx
    |> kafra_say(["Oh, my goodness! This is nonsense!"])
    |> next()
    |> cutin("", 255)
    |> castle_fire_kafra(castle_id)
    |> say([
      "....",
      "I have discharged the Kafra Employee... But... are you unsatisfied with something?"
    ])
    |> close()
  end

  defp keep_kafra(ctx) do
    ctx
    |> say(["She worked hard in my opinion. It was a good decision to keep her."])
    |> close()
  end

  defp keep_kafra_after_plea(ctx) do
    ctx
    |> kafra_say(["I'll work hard for you... Thank you!"])
    |> close()
    |> cutin("", 255)
  end

  defp offer_hire_kafra(ctx, castle_id) do
    {ctx, choice} =
      ctx
      |> say([
        "Will you contact the kafra Main Office and Hire a Employee for our Castle?",
        "^ff0000 10,000 zeny is required for their services. "
      ])
      |> next()
      |> select(["Hire.", "Cancel"])

    case choice do
      1 -> resolve_kafra_hire(ctx, castle_id)
      _ -> decline_kafra_hire(ctx)
    end
  end

  defp resolve_kafra_hire(ctx, castle_id) do
    case castle_kafra_hire_check(ctx, castle_id) do
      {:error, :contract_required} ->
        ctx
        |> say([
          "Master, we can't hire a Kafra Employee because we don't have a contract with the " <>
            "Kafra Main Office. If you want to obtain a contract with the Kafra Main Office, " <>
            "you will need to learn the Guild skill first."
        ])
        |> close()

      {:error, _reason} ->
        close(ctx)

      :ok ->
        hire_kafra(ctx, castle_id)
    end
  end

  defp hire_kafra(ctx, castle_id) do
    if zeny(ctx) < 10_000 do
      ctx
      |> say(["Well... I'm sorry but we don't have enough funds to hire a Kafra Employee."])
      |> close()
    else
      ctx
      |> pay_zeny(10_000)
      |> castle_hire_kafra(castle_id)
      |> say(["We obtained a contract with the kafra Main Office, and hired a Kafra Employee."])
      |> next()
      |> cutin("kafra_01", 2)
      |> kafra_say([
        "How do you do? I was dispatched from the Main Office.",
        "I'll do my best to not tarnish the reputation of the Guild."
      ])
      |> next()
      |> cutin("", 255)
      |> say([
        "The Contract terms of the hired Kafra Employee are for 1 month and after this term, " <>
          "you will need to pay an additional fee.",
        "It will be useful for our members."
      ])
      |> close()
    end
  end

  defp decline_kafra_hire(ctx) do
    ctx
    |> say([
      "I did as you ordered, but some of our members will be unhappy. It will be better to " <>
        "hire a Kafra Employee quickly."
    ])
    |> close()
  end

  defp master_room(ctx, _castle_id) do
    {ctx, choice} =
      ctx
      |> say([
        "Do you want to visit the room where our valuables are stored?",
        "That room is restricted to you... you are the only one with access to it."
      ])
      |> next()
      |> select(["Go into Master's room.", "Cancel"])

    handle_master_room(ctx, choice)
  end

  defp handle_master_room(ctx, 1) do
    map = strnpcinfo(ctx, 4)
    {x, y} = Map.fetch!(@master_rooms, map)

    ctx
    |> say([
      "I'll show you the secret path. Follow me...please.",
      "When you want to return here, please press the secret switch."
    ])
    |> close()
    |> warp(map, x, y)
  end

  defp handle_master_room(ctx, _cancel) do
    ctx
    |> say([
      "Goods are produced once a day... if you don't remove them in time, they will not be " <>
        "produced anymore.",
      "Therefore, it will be better if you check up on them from time to time."
    ])
    |> close()
  end

  defp say(ctx, lines), do: Enum.reduce(["[#{strnpcinfo(ctx, 1)}]" | lines], ctx, &mes(&2, &1))

  defp kafra_say(ctx, lines),
    do: Enum.reduce(["[ Hired Kafra Employee ]" | lines], ctx, &mes(&2, &1))
end
