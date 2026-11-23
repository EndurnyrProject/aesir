defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.CatPawAgent do
  @moduledoc """
  Cat Trading agent that sells save points, storage access and paid warps to players with
  enough Cat Trading Points.

  ## Behavior

  - Players with fewer than 3 points are sent to talk to the Cat Trading staff first.
  - From 3 points it saves the respawn point at the Midgard Allied Forces Post.
  - From 20 points it opens storage for 60 zeny, once the storage skill requirement is met.
  - From 40 points it warps to Midgard towns; more points unlock more towns at a lower price,
    from Prontera alone for 5500 zeny up to ten towns for 3970 zeny.
  - From 100 points it also warps to the Allied Forces Post or the other Jotunheim camp for
    5500 zeny.
  - A warp the player cannot afford ends the conversation without charging.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild02",
        x: 25,
        y: 211,
        dir: 4,
        sprite: 421,
        name: "Cat Paw Agent",
        scope: :shared,
        unique_name: "Cat Paw Agent#spl"
      },
      %{
        map: "man_fild02",
        x: 132,
        y: 47,
        dir: 4,
        sprite: 421,
        name: "Cat Paw Agent",
        scope: :shared,
        unique_name: "Cat Paw Agent#man"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCanopenstorage
  alias Aesir.ZoneServer.Script.Rathena

  @agent "[Cat Paw Agent]"

  @service_labels %{
    save: "Save your location",
    storage: "Use Storage",
    midgard_warp: "Use Cat Warp (Midgard)",
    jotunheim_warp: "Use Cat Warp (Jottunheim)",
    cancel: "Cancel"
  }

  @midgard_towns [
    "Alberta",
    "Prontera",
    "Izlude",
    "Geffen",
    "Payon",
    "Morocc",
    "Al De Baran",
    "Juno",
    "Einbroch",
    "Lighthalzen"
  ]

  @impl true
  def on_talk(ctx) do
    points = get_char_var(ctx, :ep13_yong1, 0)

    cond do
      points < 3 ->
        first_visit(ctx)

      points < 20 ->
        offer_services(ctx, points, [:save, :cancel])

      points < 40 ->
        offer_services(ctx, points, [:save, :storage, :cancel])

      points < 100 ->
        offer_services(ctx, points, [:save, :storage, :midgard_warp, :cancel])

      true ->
        offer_services(ctx, points, [:save, :storage, :midgard_warp, :jotunheim_warp, :cancel])
    end
  end

  defp first_visit(ctx) do
    ctx
    |> mes(@agent)
    |> mes("Welcome to Cat Trading.")
    |> mes("I guess you're a first-time customer, huh?")
    |> next()
    |> mes(@agent)
    |> mes("For more details about our contract, you need to talk to our staff first.")
    |> close()
  end

  defp offer_services(ctx, points, services) do
    {ctx, choice} =
      ctx
      |> mes(@agent)
      |> mes("Cat Trading's available services are as followed.")
      |> mes("For additional services, please consult Agent Gyaruk.")
      |> next()
      |> select(Enum.map(services, &Map.fetch!(@service_labels, &1)))

    service(ctx, chosen(services, choice), points)
  end

  defp service(ctx, :save, _points) do
    ctx
    |> savepoint("mid_camp", 62, 127)
    |> mes(@agent)
    |> mes(
      "Actually, residents of this village continued to offer resistance. So I shall save your location at Midgards Allied Forces Post for your safety."
    )
    |> close()
  end

  defp service(ctx, :storage, _points) do
    {ctx, can_open} = FCanopenstorage.call(ctx, [])

    cond do
      not Rathena.truthy?(can_open) ->
        ctx
        |> mes(@agent)
        |> mes("I'm sorry, but you")
        |> mes("need the Novice's")
        |> mes("Basic Skill Level 6 to")
        |> mes("use the Storage Service.")
        |> close()

      zeny(ctx) >= 60 ->
        ctx
        |> pay_zeny(60)
        |> mes(@agent)
        |> mes("Thank you.")
        |> mes("Your storage will be opened shortly.")
        |> close()
        |> openstorage()

      true ->
        ctx
        |> mes(@agent)
        |> mes("I'm sorry, but you don't")
        |> mes("have enough money?")
        |> mes("Cat Trading's storage")
        |> mes("service is 60 zeny.")
        |> mes("It's cheap, isn't it?")
        |> close()
    end
  end

  defp service(ctx, :midgard_warp, points) do
    {towns, cost} = midgard_offer(points)

    ctx
    |> mes(@agent)
    |> mes("The warp service is only")
    |> mes("available for customers with")
    |> mes("#{points} or more Cat Trading Points.")
    |> mes("Please remember, you can't come back easily once you move to Midgard.")
    |> next()
    |> midgard_town_menu(towns, cost)
  end

  defp service(ctx, :jotunheim_warp, _points) do
    {camp_name, camp} =
      if strnpcinfo(ctx, 2) == "spl",
        do: {"Manuk Camp", :manuk_camp},
        else: {"Splendide Camp", :splendide_camp}

    {ctx, choice} =
      select(ctx, ["Alliance Forces Post -> 5500z", "#{camp_name} -> 7500z", "Cancel"])

    case choice do
      1 -> catwarp(ctx, 5500, :allied_forces_post)
      2 -> catwarp(ctx, 5500, camp)
      3 -> thank_customer(ctx)
      _ -> ctx
    end
  end

  defp service(ctx, :cancel, _points), do: thank_customer(ctx)
  defp service(ctx, nil, _points), do: ctx

  defp thank_customer(ctx) do
    ctx |> mes(@agent) |> mes("Thank you for using our service.") |> close()
  end

  defp midgard_offer(points) do
    cond do
      points < 50 -> {[2], 5500}
      points < 60 -> {[1, 2], 5500}
      points < 70 -> {Enum.to_list(1..3), 5025}
      points < 80 -> {Enum.to_list(1..4), 5025}
      points < 90 -> {Enum.to_list(1..5), 4765}
      points < 100 -> {Enum.to_list(1..6), 4765}
      points < 200 -> {Enum.to_list(1..7), 4590}
      points < 250 -> {Enum.to_list(1..8), 4170}
      points < 300 -> {Enum.to_list(1..9), 4025}
      true -> {Enum.to_list(1..10), 3970}
    end
  end

  defp midgard_town_menu(ctx, towns, cost) do
    options = Enum.map(towns, &"#{Enum.at(@midgard_towns, &1 - 1)} -> #{cost}z")
    {ctx, choice} = select(ctx, options ++ ["Cancel"])

    cond do
      town = chosen(towns, choice) -> catwarp(ctx, cost, town)
      choice == length(towns) + 1 -> close(ctx)
      true -> ctx
    end
  end

  defp chosen(options, choice) when is_integer(choice) and choice >= 1,
    do: Enum.at(options, choice - 1)

  defp chosen(_options, _choice), do: nil

  defp catwarp(ctx, cost, destination) do
    if zeny(ctx) < cost do
      ctx |> mes(@agent) |> mes("Don't play with money.") |> close()
    else
      ctx |> close() |> pay_zeny(cost) |> warp_to(destination)
    end
  end

  defp warp_to(ctx, 1), do: warp(ctx, "alberta", 117, 56)
  defp warp_to(ctx, 2), do: warp(ctx, "prontera", 116, 72)

  defp warp_to(ctx, 3) do
    if Rathena.truthy?(checkre(ctx, 0)),
      do: warp(ctx, "izlude", 128, 98),
      else: warp(ctx, "izlude", 91, 105)
  end

  defp warp_to(ctx, 4), do: warp(ctx, "geffen", 120, 39)
  defp warp_to(ctx, 5), do: warp(ctx, "payon", 161, 58)
  defp warp_to(ctx, 6), do: warp(ctx, "morocc", 156, 46)
  defp warp_to(ctx, 7), do: warp(ctx, "aldebaran", 168, 112)
  defp warp_to(ctx, 8), do: warp(ctx, "yuno", 158, 125)
  defp warp_to(ctx, 9), do: warp(ctx, "einbroch", 158, 301)
  defp warp_to(ctx, 10), do: warp(ctx, "lighthalzen", 163, 64)
  defp warp_to(ctx, :splendide_camp), do: warp(ctx, "spl_fild02", 32, 225)
  defp warp_to(ctx, :manuk_camp), do: warp(ctx, "man_fild02", 129, 61)
  defp warp_to(ctx, :allied_forces_post), do: warp(ctx, "mid_camp", 62, 127)
end
