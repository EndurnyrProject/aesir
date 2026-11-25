defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Lady do
  @moduledoc """
  A Luoyang greeter who sells firecracker displays and delivers a package.

  ## Behavior

  - Offers firecrackers and delivers the quest package for a fee.

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
    spawn: [
      %{
        map: "lou_fild01",
        x: 224,
        y: 348,
        dir: 0,
        sprite: 817,
        name: "Lady",
        scope: :shared,
        unique_name: "Lady#delivery"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FF * Wait a minute! *")
        |> mes(
          "Currently, you're carrying too many items. Please put some of your things into Kafra Storage and try again.^000000"
        )
        |> close()

      get_char_var(ctx, :ch_poison, 0) < 8 ->
        greet(ctx, :before)

      get_char_var(ctx, :ch_poison, 0) == 8 ->
        delivery(ctx)

      get_char_var(ctx, :ch_poison, 0) > 8 ->
        greet(ctx, :after)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet(ctx, stage) do
    if Enum.random(1..10) > 5 do
      ctx = ctx |> mes("[Lady]") |> mes("You're at the") |> mes("entrance of Luoyang.")

      ctx =
        if stage == :before do
          ctx |> mes("I hope you enjoy") |> mes("your stay here~")
        else
          mes(ctx, "I hope you have a good time~")
        end

      ctx |> emotion(:chup) |> close()
    else
      ctx = mes(ctx, "[Lady]")

      ctx =
        if stage == :before,
          do: mes(ctx, "You're at the entrance of Luoyang."),
          else: ctx |> mes("You're at the") |> mes("entrance of") |> mes("Luoyang.")

      {ctx, choice} =
        ctx
        |> next()
        |> mes("[Lady]")
        |> mes("Luoyang is well known")
        |> mes("for its various firecrackers.")
        |> mes("Would you like to see one?")
        |> next()
        |> select(["Sure!", "No thanks~"])

      if choice == 1 do
        ctx = mes(ctx, "[Lady]")

        ctx =
          if stage == :before,
            do: mes(ctx, "Alright, there you go!"),
            else: ctx |> mes("Alright~") |> mes("There you go!")

        firecracker(ctx, stage)
      else
        ctx |> mes("[Lady]") |> mes("Hmpf...!") |> emotion(:think) |> close()
      end
    end
  end

  defp firecracker(ctx, stage) do
    ctx = if zeny(ctx) > 99, do: pay_zeny(ctx, 100), else: ctx
    ctx = close2(ctx)

    if stage == :before do
      specialeffect(ctx, :blastminebomb, :area, " #fire")
    else
      donpcevent(ctx, " #fire::OnClaymore")
    end
  end

  defp delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lady]")
      |> mes("Would you")
      |> mes("like to see some")
      |> mes("firecrackers?")
      |> next()
      |> select(["Sure!", "No thanks~"])

    if choice == 1 do
      ctx |> mes("[Lady]") |> mes("Alright,") |> mes("there you go!") |> firecracker(:delivery)
    else
      {ctx, choice} =
        ctx
        |> mes("[Lady]")
        |> mes("Hmm, if not firecrackers,")
        |> mes("then you must want something")
        |> mes("else. Did someone send you?")
        |> next()
        |> select(["Yes.", "No."])

      if choice == 1 do
        ask_sender(ctx)
      else
        ctx
        |> mes("[Lady]")
        |> mes("No...?")
        |> next()
        |> mes("[Lady]")
        |> mes("Are you...")
        |> mes("Coming on to me?")
        |> close()
      end
    end
  end

  defp ask_sender(ctx) do
    {ctx, name} =
      ctx
      |> mes("[Lady]")
      |> mes("Who was it?")
      |> mes("Please tell me")
      |> mes("his name.")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", name)

    if get_local(ctx, :"input$", "") == "Song Zhi Du" do
      deliver_package(ctx)
    else
      ctx
      |> mes("[Lady]")
      |> mes("Hmmm?")
      |> mes("I don't know who that is.")
      |> mes("So I definitely don't have")
      |> mes("a package for whoever you're")
      |> mes("talking about.")
      |> close()
    end
  end

  defp deliver_package(ctx) do
    ctx =
      ctx
      |> mes("[Lady]")
      |> mes("Oh, I see.")
      |> mes("Let me give")
      |> mes("you the package.")
      |> next()
      |> mes("[Lady]")
      |> mes("Ah, wait! I forgot!")
      |> mes("You must first pay the")
      |> mes("delivery fee of 1,000 zeny.")
      |> next()

    if zeny(ctx) > 999 do
      ctx
      |> pay_zeny(1000)
      |> give_item(7126, 1)
      |> mes("[Lady]")
      |> mes("Thank you~")
      |> mes("Now that the fee is paid,")
      |> mes("please bring this to")
      |> mes("Song Zhi Du.")
      |> mes("Take care!")
      |> set_char_var(:ch_poison, 9)
      |> changequest(11073, 11074)
      |> close()
    else
      ctx
      |> mes("[Lady]")
      |> mes("Errr...")
      |> mes(
        "You don't have enough zeny for the fee. I can't give you the package unless the delivery fee is paid!"
      )
      |> emotion(:fret)
      |> close()
    end
  end
end
