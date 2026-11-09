defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.CatPawAgent do
  @moduledoc """
  The Cat Trading agent at the expedition camp, who sells the camp as a save point, a storage
  service and Cat Warps back to Midgard as the player's Cat Trading points grow.

  ## Behavior

  - `ep13_yong1` below 1 takes the contract: "Tell me more about your services." refers the
    player to Agent Gyaruk and sets the points variable to 1, while "No. thanks" only closes.
  - 1 repeats the referral, 2 offers to save the camp as the return point (points to 3), and the
    service menu then grows with the points: save point from 3, storage from 20 (Novice Basic
    Skill 6 and 60 zeny), Cat Warp to Midgard from 40 and the Jottunheim camps above 99.
  - The warp menu depends on the points: 40 to 49 only Prontera, then Alberta to Lighthalzen are
    added tier by tier while the fee drops from 5500 to 3970 zeny.
  - Every warp charges the fee, closes the dialog and warps to the town's fixed coordinates
    (Izlude depends on the renewal flag).
  - Any other points value only yawns about wanting fish.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 62,
        y: 125,
        dir: 4,
        sprite: 421,
        name: "Cat Paw Agent",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCanopenstorage
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @storage_fee 60
  @five_towns [:alberta, :prontera, :izlude, :geffen, :payon]
  @six_towns @five_towns ++ [:morocc]
  @seven_towns @six_towns ++ [:aldebaran]
  @eight_towns @seven_towns ++ [:yuno]
  @nine_towns @eight_towns ++ [:einbroch]
  @ten_towns @nine_towns ++ [:lighthalzen]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    at_points(ctx, get_char_var(ctx, :ep13_yong1, 0))
  end

  defp at_points(ctx, points) do
    cond do
      points < 1 -> offers_the_contract(ctx)
      points == 1 -> ctx |> refers_to_gyaruk() |> close()
      points == 2 -> welcomes_the_newcomer(ctx)
      points < 20 -> offers_services(ctx, [:save])
      points < 40 -> offers_services(ctx, [:save, :storage])
      points < 100 -> offers_services(ctx, [:save, :storage, :midgard])
      points > 99 -> offers_services(ctx, [:save, :storage, :midgard, :jottunheim])
      true -> yawns(ctx)
    end
  end

  defp offers_the_contract(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cat Paw Agent]")
      |> mes("Welcome to Cat Trading.")
      |> mes("I guess you're a first-time")
      |> mes("customer, huh?")
      |> next()
      |> mes("[Cat Paw Agent]")
      |> mes("How'd you like to make")
      |> mes("a contract with us?")
      |> mes("We'll guarantee that you'll")
      |> mes("be provided with various")
      |> mes("conveniences during your")
      |> mes("stay at this expedition camp?")
      |> next()
      |> select(["Tell me more about your services.", "No. thanks"])

    case choice do
      1 ->
        ctx
        |> mes("[Cat Paw Agent]")
        |> mes(
          "Before making a contract with us, youll have to go through a few steps to satisfy our terms and conditions."
        )
        |> next()
        |> mes("[Cat Paw Agent]")
        |> mes("More clearly, you'll have to provide us something in return for our services.")
        |> mes("You know what I mean, don't you?")
        |> next()
        |> refers_to_gyaruk()
        |> set_char_var(:ep13_yong1, 1)
        |> close()

      2 ->
        ctx
        |> mes("[Cat Paw Agent]")
        |> mes("Well, feel free to come back whenever you change your mind.")
        |> close()

      _ ->
        ctx
    end
  end

  defp refers_to_gyaruk(ctx) do
    ctx
    |> mes("[Cat Paw Agent]")
    |> mes("For more information, please speak to Agent Gyaruk standing down there.")
    |> mes("I'm sure you'll find our business proposition to be very reasonable.")
  end

  defp welcomes_the_newcomer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cat Paw Agent]")
      |> mes("Thank you for making an official contract with us.")
      |> mes("You're now eligable to use our services.")
      |> next()
      |> mes("[Cat Paw Agent]")
      |> mes(
        "For our newcomers, we're offering a location-saving service with which you can save this camp as your returning location."
      )
      |> mes("Would you like to save your location?")
      |> set_char_var(:ep13_yong1, 3)
      |> next()
      |> select(["Save your location", "Cancel"])

    case choice do
      1 -> save_location(ctx)
      2 -> thanks_and_close(ctx)
      _ -> ctx
    end
  end

  defp offers_services(ctx, services) do
    {ctx, choice} =
      ctx
      |> mes("[Cat Paw Agent]")
      |> mes("Cat Trading's available services are as followed.")
      |> mes("For additional services, please consult Agent Gyaruk.")
      |> next()
      |> select(Enum.map(services, &service_label/1) ++ ["Cancel"])

    case Enum.at(services, choice - 1) do
      nil ->
        if choice == length(services) + 1, do: thanks_and_close(ctx), else: ctx

      service ->
        run_service(ctx, service)
    end
  end

  defp service_label(:save), do: "Save your location"
  defp service_label(:storage), do: "Use Storage"
  defp service_label(:midgard), do: "Use Cat Warp (Midgard)"
  defp service_label(:jottunheim), do: "Use Cat Warp (Jottunheim)"

  defp run_service(ctx, :save), do: save_location(ctx)
  defp run_service(ctx, :storage), do: storage_service(ctx)
  defp run_service(ctx, :midgard), do: warp_to_midgard(ctx)
  defp run_service(ctx, :jottunheim), do: warp_to_jottunheim_camps(ctx)

  defp yawns(ctx) do
    ctx
    |> mes("[Cat Paw Agent]")
    |> mes("*Yawn...*")
    |> mes("I want to eat fish.")
    |> close()
  end

  defp thanks_and_close(ctx) do
    ctx
    |> mes("[Cat Paw Agent]")
    |> mes("Thank you for using our service.")
    |> close()
  end

  defp save_location(ctx) do
    ctx
    |> savepoint("mid_camp", 56, 139)
    |> mes("[Cat Paw Agent]")
    |> mes("Thank you.")
    |> mes("Your location has been saved.")
    |> mes("You can now directly return to this camp.")
    |> close()
  end

  defp storage_service(ctx) do
    {ctx, allowed} = FCanopenstorage.call(ctx, [])

    cond do
      not Rathena.truthy?(allowed) ->
        ctx
        |> mes("[Cat Paw Agent]")
        |> mes("I'm sorry, but you")
        |> mes("need the Novice's")
        |> mes("Basic Skill Level 6 to")
        |> mes("use the Storage Service.")
        |> close()

      zeny(ctx) >= @storage_fee ->
        ctx
        |> pay_zeny(@storage_fee)
        |> mes("[Cat Paw Agent]")
        |> mes("Thank you.")
        |> mes("Your storage will")
        |> mes("be opened shortly.")
        |> close()
        |> openstorage()

      true ->
        ctx
        |> mes("[Cat Paw Agent]")
        |> mes("I'm sorry, but you don't")
        |> mes("have enough money?")
        |> mes("Cat Trading's storage")
        |> mes("service is 60 zeny.")
        |> mes("It's cheap, isn't it?")
        |> close()
    end
  end

  defp warp_to_midgard(ctx) do
    ctx
    |> mes("[Cat Paw Agent]")
    |> mes("The warp service is only")
    |> mes("available for customers with")
    |> mes("40 or more Cat Trading Points.")
    |> mes("Please remember, you can't come back easily once you move to Midgard.")
    |> next()
    |> offer_warps(get_char_var(ctx, :ep13_yong1, 0))
  end

  # Each tier adds one more town and drops the fee; the reference reaches them through a chain of
  # point ranges that covers every value above 39.
  defp offer_warps(ctx, points) do
    cond do
      points in 40..49 -> warps(ctx, 5500, [{"Prontera -> 5500z", :prontera}])
      points in 50..59 -> warps(ctx, 5500, midgard(5500, [:alberta, :prontera]))
      points in 60..69 -> warps(ctx, 5025, midgard(5025, [:alberta, :prontera, :izlude]))
      points in 70..79 -> warps(ctx, 5025, midgard(5025, [:alberta, :prontera, :izlude, :geffen]))
      points in 80..89 -> warps(ctx, 4765, midgard(4765, @five_towns))
      points in 90..99 -> warps(ctx, 4765, midgard(4765, @six_towns))
      points in 100..199 -> warps(ctx, 4590, midgard(4590, @seven_towns))
      points in 200..249 -> warps(ctx, 4170, midgard(4170, @eight_towns))
      points in 250..299 -> warps(ctx, 4025, midgard(4025, @nine_towns))
      true -> warps(ctx, 3970, midgard(3970, @ten_towns))
    end
  end

  defp midgard(fee, towns) do
    Enum.map(towns, fn town -> {"#{town_label(town)} -> #{fee}z", town} end)
  end

  defp town_label(:alberta), do: "Alberta"
  defp town_label(:prontera), do: "Prontera"
  defp town_label(:izlude), do: "Izlude"
  defp town_label(:geffen), do: "Geffen"
  defp town_label(:payon), do: "Payon"
  defp town_label(:morocc), do: "Morocc"
  defp town_label(:aldebaran), do: "Al De Baran"
  defp town_label(:yuno), do: "Juno"
  defp town_label(:einbroch), do: "Einbroch"
  defp town_label(:lighthalzen), do: "Lighthalzen"

  defp warp_to_jottunheim_camps(ctx) do
    {ctx, choice} =
      select(ctx, ["Splendide Camp -> 5500z", "Manuk Camp -> 5500z", "Cancel"])

    case choice do
      1 -> cat_warp(ctx, 5500, :splendide)
      2 -> cat_warp(ctx, 5500, :manuk)
      3 -> thanks_and_close(ctx)
      _ -> ctx
    end
  end

  defp warps(ctx, fee, destinations) do
    {ctx, choice} = select(ctx, Enum.map(destinations, &elem(&1, 0)) ++ ["Cancel"])

    case Enum.at(destinations, choice - 1) do
      nil ->
        if choice == length(destinations) + 1, do: close(ctx), else: ctx

      {_label, town} ->
        cat_warp(ctx, fee, town)
    end
  end

  # The reference's script-local `Catwarp`: charging the fee ends the script through the trailing
  # `end`, so the caller never continues after it.
  defp cat_warp(ctx, fee, town) do
    if zeny(ctx) < fee do
      ctx
      |> mes("[Cat Paw Agent]")
      |> mes("Don't play with money.")
      |> close()
    else
      ctx
      |> close()
      |> pay_zeny(fee)
      |> warp_to(town)
    end
  end

  defp warp_to(ctx, :izlude) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "izlude", 128, 98)
    else
      warp(ctx, "izlude", 91, 105)
    end
  end

  defp warp_to(ctx, :alberta), do: warp(ctx, "alberta", 117, 56)
  defp warp_to(ctx, :prontera), do: warp(ctx, "prontera", 116, 72)
  defp warp_to(ctx, :geffen), do: warp(ctx, "geffen", 120, 39)
  defp warp_to(ctx, :payon), do: warp(ctx, "payon", 161, 58)
  defp warp_to(ctx, :morocc), do: warp(ctx, "morocc", 156, 46)
  defp warp_to(ctx, :aldebaran), do: warp(ctx, "aldebaran", 168, 112)
  defp warp_to(ctx, :yuno), do: warp(ctx, "yuno", 158, 125)
  defp warp_to(ctx, :einbroch), do: warp(ctx, "einbroch", 158, 301)
  defp warp_to(ctx, :lighthalzen), do: warp(ctx, "lighthalzen", 163, 64)
  defp warp_to(ctx, :splendide), do: warp(ctx, "spl_fild02", 32, 225)
  defp warp_to(ctx, :manuk), do: warp(ctx, "man_fild02", 129, 61)
end
