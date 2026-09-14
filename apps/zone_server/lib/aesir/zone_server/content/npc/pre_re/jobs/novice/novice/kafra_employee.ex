defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.KafraEmployee do
  @moduledoc """
  Introduces Kafra services and transfers novices to combat training or a starting town.

  ## Behavior

  - Explains saving, storage, teleportation, and cart rental services.
  - Offers field combat or town transfers according to course progress.
  - Handles departure gifts, clears training progress, and sets the town savepoint.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-2",
        x: 118,
        y: 108,
        dir: 3,
        sprite: 117,
        name: "Kafra Employee",
        unique_name: "Kafra Employee#nv1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Welcome to")
      |> mes("Kafra Corporation.")
      |> mes("The Kafra services are")
      |> mes("always on your side.")
      |> reset_expired_registration()

    case ctx
         |> next()
         |> mes("[Kafra Employee]")
         |> mes(
           "I've been dispatched from Kafra Corporation Headquarters to assist new players such as yourself."
         )
         |> next()
         |> mes("[Kafra Employee]")
         |> mes("Please, take heed!")
         |> mes("If you move to a town")
         |> mes("^4d4dffyou will be unable to return to the Training Grounds ever again^000000.")
         |> next()
         |> select(["Teleport Service", "About Kafra services"]) do
      {ctx, 1} -> teleport_menu(ctx)
      {ctx, 2} -> services_introduction(ctx)
      {ctx, _choice} -> ctx
    end
  end

  defp reset_expired_registration(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :NEW_MES_FLAG0, 0)) do
      ctx
      |> set_char_var(:NEW_MES_FLAG0, 0)
      |> set_char_var(:NEW_MES_FLAG1, 0)
      |> set_char_var(:NEW_MES_FLAG2, 0)
      |> set_char_var(:NEW_MES_FLAG3, 0)
      |> set_char_var(:NEW_MES_FLAG4, 0)
      |> set_char_var(:NEW_MES_FLAG5, 0)
      |> set_char_var(:NEW_LVUP0, 0)
      |> set_char_var(:NEW_LVUP1, 0)
      |> set_char_var(:NEW_JOBLVUP, 0)
    else
      ctx
    end
  end

  defp teleport_menu(ctx) do
    if no_essential_courses_started?(ctx) do
      first_town_menu(ctx)
    else
      course_or_town_menu(ctx)
    end
  end

  defp no_essential_courses_started?(ctx) do
    get_char_var(ctx, :nov_get_item02, 0) < 10 and
      get_char_var(ctx, :nov_get_item03, 0) < 10 and
      get_char_var(ctx, :nov_get_item04, 0) < 10
  end

  defp first_town_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes(
        "I see, you must want to teleport to a town in Rune-Midgarts imediately. First, let me briefly inform you about the different towns and cities in Ragnarok."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "Prontera is the capital of the Rune-Midgarts kingdom, and its satellite, Izlude, is closeby."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "^996633Morocc^000000 is in the desert. It's the town where you can change your job to the Thief and Assassin classes."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "^006600Payon^000000 is in the mountains, and is famous for its Archer Village, where Novices can change their jobs to Archers."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "The city of magic, ^993300Geffen^000000, is where people go to become Mages and Wizards."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "^003399Alberta^000000, the port city, is where the Merchant Guild is located. You must also go to Alberta if you wish to travel by sea."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Please choose")
      |> mes("your destination.")
      |> next()
      |> select(["Prontera", "Morocc", "Payon", "Alberta", "Geffen"])

    travel_to_town(ctx, destination(choice), :first_departure)
  end

  defp course_or_town_menu(ctx) do
    case select(ctx, [
           "Field Combat Course",
           "Prontera",
           "Morocc",
           "Payon",
           "Alberta",
           "Geffen"
         ]) do
      {ctx, 1} ->
        ctx
        |> mes("[Kafra Employee]")
        |> mes("Thank you, let")
        |> mes("me send you to the")
        |> mes("Field Combat Training Course.")
        |> close()
        |> warp("new_1-2", 28, 178)

      {ctx, choice} ->
        travel_to_town(ctx, destination(choice - 1), :returning_departure)
    end
  end

  defp destination(1), do: {"Prontera", "prontera", 117, 72, 150, 50}
  defp destination(2), do: {"Morocc", "morocc", 150, 99, 155, 110}
  defp destination(3), do: {"Payon", "payon", 70, 100, 166, 67}
  defp destination(4), do: {"Alberta", "alberta", 30, 232, 114, 58}
  defp destination(5), do: {"Geffen", "geffen", 119, 37, 122, 65}

  defp travel_to_town(
         ctx,
         {destination, map, save_x, save_y, warp_x, warp_y},
         departure_type
       ) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("You have decided")
    |> mes("to go to #{destination}.")
    |> mes("May God be with you.")
    |> close()
    |> departure_gifts(departure_type)
    |> clear_training_progress()
    |> savepoint(map, save_x, save_y)
    |> warp(map, warp_x, warp_y)
  end

  defp departure_gifts(ctx, :first_departure) do
    if get_char_var(ctx, :nov_get_item05, 0) < 11 do
      ctx
      |> set_char_var(:nov_get_item05, 11)
      |> give_item(569, 100)
      |> give_item(1243, 1)
      |> give_item(2414, 1)
      |> give_item(2510, 1)
      |> give_item(2352, 1)
      |> give_item(2112, 1)
      |> give_item(601, 10)
      |> give_item(602, 2)
      |> give_item(7059, 5)
      |> give_item(7060, 5)
    else
      ctx
    end
  end

  defp departure_gifts(ctx, :returning_departure) do
    if get_char_var(ctx, :nov_get_item05, 0) < 11 do
      ctx
      |> set_char_var(:nov_get_item05, 11)
      |> give_item(7059, 5)
      |> give_item(7060, 5)
    else
      ctx
    end
  end

  defp clear_training_progress(ctx) do
    ctx
    |> set_char_var(:nov_1st_cos, 0)
    |> set_char_var(:nov_2nd_cos, 0)
    |> set_char_var(:nov_3_swordman, 0)
    |> set_char_var(:nov_3_archer, 0)
    |> set_char_var(:nov_3_thief, 0)
    |> set_char_var(:nov_3_magician, 0)
    |> set_char_var(:nov_3_acolyte, 0)
    |> set_char_var(:nov_3_merchant, 0)
  end

  defp services_introduction(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Let me introduce you")
    |> mes("to the Kafra Services.")
    |> mes("In the menu, please choose")
    |> mes("the service you'd like to")
    |> mes("learn more about.")
    |> next()
    |> services_menu()
  end

  defp services_menu(ctx) do
    case select(ctx, [
           "Save service",
           "Storage service",
           "Teleport service",
           "Cart rental service",
           "Cancel"
         ]) do
      {ctx, 1} -> ctx |> save_service_lesson() |> services_menu()
      {ctx, 2} -> ctx |> storage_service_lesson() |> services_menu()
      {ctx, 3} -> ctx |> teleport_service_lesson() |> services_menu()
      {ctx, 4} -> ctx |> cart_service_lesson() |> services_menu()
      {ctx, 5} -> ctx |> mes("[Kafra Employee]") |> mes("Thank you.") |> close()
      {ctx, _choice} -> services_menu(ctx)
    end
  end

  defp save_service_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes(
        "When you talk to a Kafra Employee and ask for the Save Service, the location of where you will revive, after being defeated in battle, will be changed."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "Your Respawn Point is always the last place where you have saved. Using a Butterfly Wing will return you to the place where you"
      )
      |> mes("last saved.")
      |> next()
      |> mes("[Kafra Employoee]")
      |> mes("The Save Service")
      |> mes("is also provided by")
      |> mes("the Kafra Corporation")
      |> mes("free of charge~!")

    ctx =
      if get_char_var(ctx, :nov_1st_cos, 0) < 20 do
        ctx
        |> set_char_var(:nov_1st_cos, 20)
        |> grant_base_experience()
      else
        ctx
      end

    next(ctx)
  end

  defp storage_service_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Kafra Employee]")
      |> mes(
        "The Kafra Corporation is the world's largest company with a long and distinguished history on the Midgard continent."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("You can store and retrieve")
      |> mes(
        "your items in any town at your convenience. This Storage is shared by every character on one account."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "It's unreasonable to carry all of your items with you when you don't need them right away. Please use our Storage and keep your items safe and secure."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Our convenient Storage Service")
      |> mes("is provided to our customers for a small fee which is different from town to town.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("However, you must be")
      |> mes("at least ^3355FFBasic Skill Level 6^000000")
      |> mes("to use the Storage.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "There are 3 different item sections of the Storage into which items are organized: Consumable, Equipment and Etc."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "There are a maximum of 300 Inventory Slots in Kafra Storage, meaning you can have up to 300 different kinds of items in Storage."
      )
      |> next()
      |> mes("[Kafra Employee]")
      |> mes(
        "Remember though, that in the case of Equipment, each item takes up one Inventory Slot. The maximum number of items that can be placed in Kafra Storage is 30,000."
      )

    ctx =
      if get_char_var(ctx, :nov_3_archer, 0) < 20 and job_level(ctx) < 7 do
        ctx
        |> set_char_var(:nov_3_archer, 20)
        |> grant_job_experience()
      else
        ctx
      end

    next(ctx)
  end

  defp teleport_service_lesson(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("The Kafra Corporation")
    |> mes(
      "provides our valued customers with a convenient Teleport Service which greatly cuts down on your"
    )
    |> mes("traveling time.")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes(
      "Our Teleport Service is safe and comfortable, and will allow you to fully explore the various lands of the Midgard continent."
    )
    |> next()
    |> mes("[Kafra Employee]")
    |> mes(
      "We thank our valued customers for their great support and continue to provide them with the best"
    )
    |> mes("of service.")
    |> next()
  end

  defp cart_service_lesson(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("The Kafra Corporation")
    |> mes("provides a Cart Rental Service to Merchants, as well as Blacksmiths and Alchemists.")
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("The flamboyantly mysterious")
    |> mes(
      "^CE6300Super Novice^000000 can use Carts, but we officially don't have a contract with that class. Still, somehow..."
    )
    |> next()
    |> mes("[Kafra Employee]")
    |> mes(
      "Anyway, Merchants, Blacksmiths and Alchemists must also learn the ^3355FFPush Cart^000000 skill in order to be able to rent a cart."
    )
    |> next()
    |> mes("[Kafra Employee]")
    |> mes("The Cart Rental service")
    |> mes("charge will differ from")
    |> mes("town to town.")
    |> next()
  end

  defp grant_base_experience(ctx) do
    case base_level(ctx) do
      1 -> getexp(ctx, 10, 0)
      2 -> getexp(ctx, 17, 0)
      3 -> getexp(ctx, 26, 0)
      4 -> getexp(ctx, 37, 0)
      5 -> getexp(ctx, 78, 0)
      6 -> getexp(ctx, 115, 0)
      7 -> getexp(ctx, 155, 0)
      _level -> ctx
    end
  end

  defp grant_job_experience(ctx) do
    case job_level(ctx) do
      1 -> getexp(ctx, 0, 10)
      2 -> getexp(ctx, 0, 18)
      3 -> getexp(ctx, 0, 28)
      4 -> getexp(ctx, 0, 40)
      5 -> getexp(ctx, 0, 91)
      6 -> getexp(ctx, 0, 151)
      _level -> ctx
    end
  end
end
