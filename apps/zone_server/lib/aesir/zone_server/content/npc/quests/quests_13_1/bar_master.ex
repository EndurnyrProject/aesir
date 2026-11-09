defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.BarMaster do
  @moduledoc """
  Karred, the bar master of the tavern in the ruined eastern Morocc, who sells drinks and
  passes an Assassin on to Rin.

  ## Behavior

  - Turns away a player who would be carrying too much to receive a drink.
  - Menu: order a drink, ask about the mission, or quit.
  - Sells Tropical Sograt or Vermilion on the Beach for 1,000 zeny, or 800 zeny to an
    Assassin, after the inventory-space and weight checks the reference asks for.
  - For an Assassin, points the player at Rin in the inner room, setting `mao_morocc2` to 5
    on the first visit and reacting to the later steps on repeat visits.
  - For everyone else, tells them where the mission stands and lets a player on step 4 ask
    for Rin, which also sets `mao_morocc2` to 5.

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
        map: "que_job01",
        x: 82,
        y: 95,
        dir: 3,
        sprite: 46,
        name: "Bar Master",
        scope: :shared,
        unique_name: "Bar Master#moc2_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @tropical_sograt 12112
  @vermilion_on_the_beach 12113

  @regular_price 1000
  @assassin_price 800
  @weight_reserve 2000

  @juice_note [
    "This drink is mainly made of fruit juice,",
    "but you still shouldn't drink too much."
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      overburdened(ctx)
    else
      {ctx, choice} =
        ctx
        |> greet()
        |> next()
        |> select(["Order a Drink", "About the mission", "Quit"])

      case choice do
        1 -> drink_menu(ctx)
        2 -> mission(ctx)
        3 -> quit(ctx)
        _ -> ctx
      end
    end
  end

  defp overburdened(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp greet(ctx) do
    ctx = mes(ctx, "[Karred]")

    if assassin?(ctx) do
      ctx
      |> mes("Welcome.")
      |> mes("Care for a drink?")
    else
      mes(ctx, "What would you like to drink?")
    end
  end

  defp drink_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Karred]")
      |> mes("We have Tropical Sograt")
      |> mes("and Vermillion on the Beach.")
      |> mes("Which one would you like to drink?")
      |> next()
      |> select(["Tropical Sograt", "Vermilion on the Beach", "How about a free drink?"])

    case choice do
      1 -> order_tropical_sograt(ctx)
      2 -> order_vermilion_on_the_beach(ctx)
      3 -> get_out(ctx)
      _ -> ctx
    end
  end

  defp order_tropical_sograt(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      too_loaded_for_a_glass(ctx)
    else
      ctx
      |> serve(@tropical_sograt, ["Here, drink up." | @juice_note], @juice_note)
      |> close()
    end
  end

  defp order_vermilion_on_the_beach(ctx) do
    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < @weight_reserve do
      too_loaded_for_a_glass(ctx)
    else
      ctx
      |> serve(@vermilion_on_the_beach, ["Here, enjoy."], ["Don't drink too much, alright?"])
      |> close()
    end
  end

  defp too_loaded_for_a_glass(ctx) do
    ctx
    |> mes("[Karred]")
    |> mes("Are you sure you can even hold a glass of alcohol?")
    |> mes("You're carrying too many things on you already.")
    |> close()
  end

  # The reference charges the discounted price to an Assassin and the full price to everyone
  # else, and refuses each with its own lines when the zeny is short.
  defp serve(ctx, item, discount_tail, regular_tail) do
    ctx = mes(ctx, "[Karred]")

    cond do
      assassin?(ctx) and zeny(ctx) < @assassin_price ->
        ctx
        |> mes("I can give you a special discount, but")
        |> mes("you don't have enough money to even pay the special price.")
        |> mes("Why don't you check your money first?")
        |> mes("This drink is only 800 zeny for Assassins!")

      assassin?(ctx) ->
        ctx
        |> mes("I'll give you a special discount.")
        |> say(discount_tail)
        |> pay_zeny(@assassin_price)
        |> give_item(item, 1)

      zeny(ctx) < @regular_price ->
        ctx
        |> mes("Do you even have any money?")
        |> mes("Why don't you check your money first?")
        |> mes("It's 1000 zeny for one glass.")

      true ->
        ctx
        |> mes("There you go.")
        |> say(regular_tail)
        |> pay_zeny(@regular_price)
        |> give_item(item, 1)
    end
  end

  defp mission(ctx) do
    if assassin?(ctx), do: assassin_mission(ctx), else: outsider_mission(ctx)
  end

  defp assassin_mission(ctx) do
    ctx =
      ctx
      |> mes("[Karred]")
      |> mes("How many I help you?")
      |> next()

    case get_char_var(ctx, :mao_morocc2, 0) do
      4 -> meet_rin(ctx)
      step when step > 4 -> rin_convalescing(ctx)
      _step -> open_invitation(ctx)
    end
  end

  defp meet_rin(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Karred]")
      |> mes("...Rin? I see. So you're assisting Mr. Kidd.")
      |> mes("Rin...she's in the room inside.")
      |> mes("She was gravely injured not that long ago...")
      |> next()
      |> select(["?"])

    ctx
    |> mes("[Karred]")
    |> mes("You can't expect your job to always go smoothly.")
    |> mes("Of course there will be risks.")
    |> mes("Why don't you go pay her a visit?")
    |> set_char_var(:mao_morocc2, 5)
    |> close()
  end

  defp rin_convalescing(ctx) do
    ctx
    |> mes("[Karred]")
    |> mes("Rin needs to rest for now. I hope you'll do what you can to help her out.")
    |> mes("But please do take care of yourself as well.")
    |> next()
    |> mes("[Karred]")
    |> mes("You and Rin are like my children to me, and such injuries...")
    |> mes("Sigh...it's torture for me to see.")
    |> close()
  end

  defp open_invitation(ctx) do
    ctx
    |> mes("[Karred]")
    |> mes(
      "I hope you'll come by more often. This place is open to you always, even if you don't have missions."
    )
    |> close()
  end

  defp outsider_mission(ctx) do
    if get_char_var(ctx, :mao_morocc2, 0) > 4 do
      rin_bedridden(ctx)
    else
      recommendation_expired(ctx)
    end
  end

  defp rin_bedridden(ctx) do
    ctx
    |> mes("[Karred]")
    |> mes("Rin needs to rest in bed for a while. I hope you'll help her complete her duties.")
    |> mes("...This is quite embarrassing to admit, but I see her like my own daughter.")
    |> next()
    |> mes("[Litheron]")
    |> mes("Ah, just forget what I said. That was out of line.")
    |> mes("I guess I'm drunk after dealing with alcohol all day.")
    |> close()
  end

  defp recommendation_expired(ctx) do
    ctx =
      ctx
      |> mes("[Karred]")
      |> mes("How may I help you?")
      |> mes(
        "For your information, the 'recommendation' has lost its effect. You'd better go back."
      )

    if get_char_var(ctx, :mao_morocc2, 0) == 4 do
      ask_for_rin(ctx)
    else
      close(ctx)
    end
  end

  defp ask_for_rin(ctx) do
    {ctx, _} = ctx |> next() |> select(["I'm here for Rin!"])

    ctx
    |> mes("[Karred]")
    |> mes("...? Why are you looking for Rin?")
    |> next()
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Karred]")
    |> mes("I see. So you're a member of the Ash Vacuum expedition.")
    |> mes("Rin is in the inner room.")
    |> mes(
      "...She's been badly injured and is resting in bed. Don't do anything to shock her, alright?"
    )
    |> set_char_var(:mao_morocc2, 5)
    |> close()
  end

  defp quit(ctx) do
    ctx
    |> mes("[Karred]")
    |> mes("Hmmm.")
    |> close()
  end

  defp get_out(ctx) do
    ctx
    |> mes("[Karred]")
    |> mes(".........")
    |> mes("Get out.")
    |> close()
  end

  defp say(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))

  defp assassin?(ctx), do: Rathena.job_id(base_class(ctx)) == Rathena.job_id(:assassin)
end
