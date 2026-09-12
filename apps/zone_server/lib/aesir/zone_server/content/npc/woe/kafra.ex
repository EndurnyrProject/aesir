defmodule Aesir.ZoneServer.Content.Npc.Woe.Kafra do
  @moduledoc """
  Castle Kafra: one placement per FE castle offering the owning guild's
  members storage, a 200 zeny teleport to the castle's town, and an 800 zeny
  pushcart rental. Refuses anyone outside the owning guild by name.

  Visibility is not this module's concern: the placement is always
  registered, and the castle services module enables or disables it by its
  `unique_name` (`"Kafra Employee#<castle map>"`) as the castle changes hands.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{
        map: "aldeg_cas01",
        x: 218,
        y: 170,
        dir: 0,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#aldeg_cas01"
      },
      %{
        map: "aldeg_cas02",
        x: 84,
        y: 74,
        dir: 0,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#aldeg_cas02"
      },
      %{
        map: "aldeg_cas03",
        x: 118,
        y: 76,
        dir: 0,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#aldeg_cas03"
      },
      %{
        map: "aldeg_cas04",
        x: 45,
        y: 88,
        dir: 0,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#aldeg_cas04"
      },
      %{
        map: "aldeg_cas05",
        x: 31,
        y: 190,
        dir: 0,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#aldeg_cas05"
      },
      %{
        map: "gefg_cas01",
        x: 83,
        y: 47,
        dir: 3,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#gefg_cas01"
      },
      %{
        map: "gefg_cas02",
        x: 23,
        y: 66,
        dir: 3,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#gefg_cas02"
      },
      %{
        map: "gefg_cas03",
        x: 116,
        y: 89,
        dir: 5,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#gefg_cas03"
      },
      %{
        map: "gefg_cas04",
        x: 59,
        y: 70,
        dir: 3,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#gefg_cas04"
      },
      %{
        map: "gefg_cas05",
        x: 61,
        y: 52,
        dir: 5,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#gefg_cas05"
      },
      %{
        map: "payg_cas01",
        x: 128,
        y: 58,
        dir: 3,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#payg_cas01"
      },
      %{
        map: "payg_cas02",
        x: 22,
        y: 275,
        dir: 5,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#payg_cas02"
      },
      %{
        map: "payg_cas03",
        x: 9,
        y: 263,
        dir: 5,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#payg_cas03"
      },
      %{
        map: "payg_cas04",
        x: 40,
        y: 235,
        dir: 1,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#payg_cas04"
      },
      %{
        map: "payg_cas05",
        x: 276,
        y: 227,
        dir: 1,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#payg_cas05"
      },
      %{
        map: "prtg_cas01",
        x: 96,
        y: 173,
        dir: 0,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#prtg_cas01"
      },
      %{
        map: "prtg_cas02",
        x: 71,
        y: 36,
        dir: 4,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#prtg_cas02"
      },
      %{
        map: "prtg_cas03",
        x: 181,
        y: 215,
        dir: 4,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#prtg_cas03"
      },
      %{
        map: "prtg_cas04",
        x: 258,
        y: 247,
        dir: 4,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#prtg_cas04"
      },
      %{
        map: "prtg_cas05",
        x: 52,
        y: 41,
        dir: 4,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#prtg_cas05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCanopenstorage
  alias Aesir.ZoneServer.Script.Rathena

  @destinations %{
    "aldeg" => {"Al De Baran", "aldebaran", 132, 103},
    "gefg" => {"Geffen", "geffen", 120, 39},
    "payg" => {"Payon", "payon", 70, 100},
    "prtg" => {"Prontera", "prontera", 278, 211}
  }

  @impl true
  def on_talk(ctx) do
    case castle_at(ctx) do
      nil -> close(ctx)
      castle_id -> handle_castle(ctx, castle_id)
    end
  end

  defp handle_castle(ctx, castle_id) do
    ctx = cutin(ctx, "kafra_01", 2)
    owner = castle_owner(ctx, castle_id)

    if owner != nil and owner == getcharid(ctx, 2) do
      greet_member(ctx, owner)
    else
      refuse(ctx, [
        "I am instructed to only offer my services to the ^ff0000#{getguildname(ctx, owner)}" <>
          "^000000 Guild. Please try another Kafra Employee around here. Sorry for the " <>
          "inconvenience."
      ])
    end
  end

  defp greet_member(ctx, owner) do
    {ctx, choice} =
      ctx
      |> say([
        "Welcome. ^ff0000#{getguildname(ctx, owner)}^000000 Member.",
        "The Kafra Corporation will stay with you wherever you go."
      ])
      |> next()
      |> select(["Use Storage", "Use Teleport Service", "Rent a Pushcart", "Cancel"])

    handle_menu(ctx, choice)
  end

  defp handle_menu(ctx, 1), do: storage(ctx)
  defp handle_menu(ctx, 2), do: teleport(ctx)
  defp handle_menu(ctx, 3), do: cart(ctx)
  defp handle_menu(ctx, _cancel), do: cancel(ctx)

  defp storage(ctx) do
    {ctx, can_open} = FCanopenstorage.call(ctx, [])

    if Rathena.truthy?(can_open) do
      ctx
      |> say([
        "Here, let me open",
        "your Storage for you.",
        "Thank you for using",
        "the Kafra Service."
      ])
      |> close()
      |> openstorage()
      |> cutin("", 255)
    else
      refuse(ctx, [
        "I'm sorry, but you",
        "need the Novice's",
        "Basic Skill Level 6 to",
        "use the Storage Service."
      ])
    end
  end

  defp teleport(ctx) do
    {town_name, town_map, x, y} = destination(ctx)

    {ctx, choice} =
      ctx
      |> say(["Please choose", "your destination."])
      |> next()
      |> select(["#{town_name} -> 200z", "Cancel"])

    handle_teleport(ctx, choice, town_name, town_map, x, y)
  end

  defp handle_teleport(ctx, 1, town_name, town_map, x, y) do
    if zeny(ctx) < 200 do
      refuse(ctx, [
        "I'm sorry, but you don't have",
        "enough zeny for the Teleport",
        "Service. The fee to teleport",
        "to #{town_name} is 200 zeny."
      ])
    else
      ctx
      |> pay_zeny(200)
      |> close()
      |> warp(town_map, x, y)
    end
  end

  defp handle_teleport(ctx, _cancel, _town_name, _town_map, _x, _y), do: dismiss(ctx)

  defp destination(ctx) do
    prefix = ctx.game_state.map_name |> String.split("_") |> hd()
    Map.fetch!(@destinations, prefix)
  end

  defp cart(ctx) do
    cond do
      getskilllv(ctx, :mc_pushcart) < 1 ->
        refuse(ctx, [
          "I'm sorry, but the",
          "Pushcart rental service",
          "is only available to Merchants,",
          "Blacksmiths, Master Smiths,",
          "Alchemists, Biochemists,",
          "Mechanics and Geneticists."
        ])

      checkcart(ctx) == 1 ->
        refuse(ctx, [
          "You already have",
          "a Pushcart equipped.",
          "Unfortunately, we can't",
          "rent more than one to",
          "each customer at a time."
        ])

      true ->
        offer_cart(ctx)
    end
  end

  defp offer_cart(ctx) do
    {ctx, choice} =
      ctx
      |> say([
        "The Pushcart rental",
        "fee is 800 zeny. Would",
        "you like to rent a Pushcart?"
      ])
      |> next()
      |> select(["Rent a Pushcart.", "Cancel"])

    handle_cart_offer(ctx, choice)
  end

  defp handle_cart_offer(ctx, 1) do
    if zeny(ctx) < 800 do
      refuse(ctx, [
        "I'm sorry, but you",
        "don't have enough",
        "zeny to pay the Pushcart",
        "rental fee of 800 zeny."
      ])
    else
      ctx |> pay_zeny(800) |> setcart() |> close() |> cutin("", 255)
    end
  end

  defp handle_cart_offer(ctx, _cancel), do: dismiss(ctx)

  defp cancel(ctx) do
    refuse(ctx, [
      "We, here at Kafra Corporation, are always endeavoring to provide you with the best " <>
        "services. We hope that we meet your adventuring needs and standards of excellence."
    ])
  end

  defp refuse(ctx, lines), do: ctx |> say(lines) |> dismiss()

  defp dismiss(ctx), do: ctx |> close() |> cutin("", 255)

  defp say(ctx, lines), do: Enum.reduce(["[Kafra Employee]" | lines], ctx, &mes(&2, &1))
end
