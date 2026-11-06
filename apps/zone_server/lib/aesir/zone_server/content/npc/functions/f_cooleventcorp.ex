defmodule Aesir.ZoneServer.Content.Npc.Functions.FCooleventcorp do
  @moduledoc """
  Runs the Cool Event Corp. staff counter.

  ## Behavior

  The menu comes from the NPC, which decides whether save, storage, teleport, pushcart and the
  storage password service are offered. Saving stores the respawn point the NPC passes in, storage
  costs 40 zeny once the Basic Skill requirement is met, teleport costs 2200 zeny (4400 without an
  active VIP status) to the NPC's destination, and the pushcart is free with a ticket or 800 zeny.
  The password service hands over to `F_SetKafCode`, and the last option is a feedback message.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/cool_event_corp.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Content.Npc.Functions.FCanopenstorage
  alias Aesir.ZoneServer.Content.Npc.Functions.FCheckkafcode
  alias Aesir.ZoneServer.Content.Npc.Functions.FSetkafcode
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @staff "[Cool Event Corp. Staff]"
  @storage_fee 40
  @cart_fee 800
  @warp_fee 2200
  @warp_fee_no_vip 4400
  @warp_ticket 7060
  @cart_ticket 7061
  @pushcart_skill 39

  @feedback [
    "Cool Event Corp. is always",
    "striving to provide the best",
    "services for our customers.",
    "Help us become the best by",
    "providing us with your opinions",
    "and honest feedback. Thank you."
  ]

  @destinations %{
    "Veins" => {"veins", 205, 101},
    "Rachel" => {"rachel", 115, 125}
  }

  @doc """
  Callable rAthena global function
  `F_CoolEventCorp(menu, location, save_map, save_x, save_y, warp_map)`; throws
  `{:script_end, ctx}` after the chosen service.
  """
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    {ctx, choice} =
      ctx
      |> cutin("zonda_01", 2)
      |> mes(@staff)
      |> mes("Welcome to Cool Event Corp.")
      |> mes("Our staff is always working")
      |> mes("to surpass your expactations")
      |> mes("for quality service. So how")
      |> mes("may I assist you today?")
      |> next()
      |> select(menu(args))

    ctx =
      try do
        dispatch(ctx, choice, args)
      catch
        :throw, {:brk_1, ctx} -> ctx
      end

    halt(ctx |> cutin("", 255))
  end

  defp menu(args), do: args |> Enum.at(0, 0) |> to_string() |> String.split(":")

  defp dispatch(ctx, 1, args), do: save_respawn(ctx, args)
  defp dispatch(ctx, 2, _args), do: storage(ctx)
  defp dispatch(ctx, 3, args), do: teleport(ctx, args)
  defp dispatch(ctx, 4, _args), do: pushcart(ctx)
  defp dispatch(ctx, 5, _args), do: password_service(ctx)
  defp dispatch(ctx, _other, _args), do: feedback(ctx)

  defp save_respawn(ctx, args) do
    ctx
    |> mes(@staff)
    |> mes("Your Respawn Point")
    |> mes("has been saved here")
    |> mes("#{Enum.at(args, 1, 0)}.")
    |> mes("Thank you for using the")
    |> mes("Cool Event Corp. service~")
    |> savepoint(Enum.at(args, 2, 0), Enum.at(args, 3, 0), Enum.at(args, 4, 0))
    |> close()
  end

  defp storage(ctx) do
    {ctx, allowed} = ctx |> mes(@staff) |> FCanopenstorage.call([])

    cond do
      not Rathena.truthy?(allowed) ->
        ctx
        |> mes("I'm sorry, but you")
        |> mes("need the Novice's")
        |> mes("Basic Skill Level 6 to")
        |> mes("use the Storage Service.")
        |> close()
        |> brk()

      zeny(ctx) < @storage_fee ->
        ctx
        |> mes("I'm sorry, but you don't")
        |> mes("have enough Zeny to use")
        |> mes("the Storage Service. Our")
        |> mes("Storage access fee is 40 Zeny.")
        |> close()
        |> brk()

      true ->
        {ctx, _code} =
          ctx
          |> pay_zeny(@storage_fee)
          |> mes("Let me open your personal")
          |> mes("storage for you right away.")
          |> mes("Thanks for supporting Cool")
          |> mes("Event Corp. by using our")
          |> mes("services. Have a good day~")
          |> FCheckkafcode.call([])

        ctx |> close() |> openstorage()
    end
  end

  defp teleport(ctx, args) do
    ctx = ctx |> mes("Please choose") |> mes("your destination.") |> next()

    cost = if no_vip_surcharge?(ctx), do: @warp_fee_no_vip, else: @warp_fee
    destination = Enum.at(args, 5, 0)

    {ctx, choice} = select(ctx, String.split("#{destination} -> #{cost} z:Cancel", ":"))

    ctx = if choice == 1, do: take_teleport(ctx, destination, cost), else: ctx
    close(ctx)
  end

  defp take_teleport(ctx, destination, cost) do
    if count_item(ctx, @warp_ticket) != 0 or zeny(ctx) >= cost do
      ctx =
        if count_item(ctx, @warp_ticket) != 0,
          do: delitem(ctx, @warp_ticket, 1),
          else: pay_zeny(ctx, cost)

      ctx
      |> warp_to(destination)
      |> cutin("", 255)
      |> halt()
    else
      ctx
      |> mes(@staff)
      |> mes("I'm sorry, but you don't have")
      |> mes("enough zeny for the Teleport")
      |> mes("Service. The fee to teleport")
      |> mes("to #{destination} is #{cost} zeny.")
    end
  end

  defp warp_to(ctx, destination) do
    case Map.fetch(@destinations, destination) do
      {:ok, {map, x, y}} -> warp(ctx, map, x, y)
      :error -> ctx
    end
  end

  defp pushcart(ctx) do
    ctx = mes(ctx, @staff)

    if base_class(ctx) != :merchant do
      brk(not_merchant(ctx))
    end

    if getskilllv(ctx, @pushcart_skill) == 0 do
      brk(
        ctx
        |> mes("You can only rent a cart after")
        |> mes("learning the Pushcart Skill.")
        |> close()
      )
    end

    if checkcart(ctx) == 1 do
      brk(
        ctx
        |> mes("You already have")
        |> mes("a Pushcart equipped.")
        |> mes("Unfortunately, we can't")
        |> mes("rent more than one to")
        |> mes("each customer at a time.")
        |> close()
      )
    end

    if Rathena.truthy?(count_item(ctx, @cart_ticket)) do
      brk(ctx |> delitem(@cart_ticket, 1) |> setcart() |> close())
    end

    ctx |> rent_cart() |> close()
  end

  defp not_merchant(ctx) do
    ctx =
      ctx
      |> mes("I'm sorry, but the")
      |> mes("Pushcart rental service")

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        mes(ctx, "is only available to Merchant classes.")
      else
        ctx
        |> mes("is only available to Merchants,")
        |> mes("Blacksmiths, White Smiths,")
        |> mes("Alchemists and Creators.")
      end

    close(ctx)
  end

  defp rent_cart(ctx) do
    {ctx, choice} =
      ctx
      |> mes("The Pushcart rental")
      |> mes("fee is 800 Zeny. Would")
      |> mes("you like to rent a Pushcart?")
      |> next()
      |> select(["Rent a Pushcart", "Cancel"])

    if choice == 1 do
      if zeny(ctx) < @cart_fee do
        ctx
        |> mes(@staff)
        |> mes("I'm sorry, but you")
        |> mes("don't have enough")
        |> mes("Zeny to pay the Pushcart")
        |> mes("rental fee of 800 Zeny.")
      else
        ctx |> pay_zeny(@cart_fee) |> setcart()
      end
    else
      ctx
    end
  end

  defp password_service(ctx) do
    {ctx, _password} = FSetkafcode.call(ctx, [@staff, "Cool Event Corp."])
    feedback(ctx)
  end

  defp feedback(ctx) do
    Enum.reduce(@feedback, mes(ctx, @staff), &mes(&2, &1)) |> close()
  end

  defp no_vip_surcharge?(ctx) do
    Rathena.truthy?(get_char_var(ctx, :VIP_SCRIPT, 0)) and not Rathena.truthy?(vip_status(ctx, 1))
  end

  defp brk(ctx), do: throw({:brk_1, ctx})
  defp halt(ctx), do: throw({:script_end, ctx})
end
