defmodule Aesir.ZoneServer.Content.Npc.Kafras.Kafras.KafraService do
  @moduledoc """
  Kafra Leilah at the Kafra Corporation Headquarters in Al De Baran, who serves players in person
  instead of through the standard Kafra menu.

  ## Behavior

  - Saves the respawn point inside the headquarters.
  - Opens the player's storage for the 20 zeny access fee, which also adds the reserve points the
    fee is worth.
  - Refuses the storage service when the player cannot pay the fee, and explains that she has no
    pushcart to rent because she is not on duty.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - kobra_k88
    - Samuray22
    - Evera
    - Lupus
    - Euphy
    - Lemongrass

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/kafras.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 96,
        y: 181,
        dir: 4,
        sprite: 113,
        name: "Kafra Service",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCheckkafcode
  alias Aesir.ZoneServer.Script.Ctx

  @storage_fee 20
  @reserve_point_divisor 5

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("kafra_05", 2)
      |> mes("[Kafra Leilah]")
      |> mes("Hm...?")
      |> mes("Oh, welcome to")
      |> mes("the Kafra Corporation")
      |> mes("Headquarters. Did you")
      |> mes("need something?")
      |> next()
      |> select(["Save", "Use Storage", "Rent a Pushcart", "Cancel"])

    case choice do
      1 -> save(ctx)
      2 -> use_storage(ctx)
      3 -> rent_pushcart(ctx)
      4 -> cancel(ctx)
      _other -> cutin(ctx, "", 255)
    end
  end

  defp save(ctx) do
    ctx
    |> mes("[Kafra Leilah]")
    |> mes("Your Respawn Point has")
    |> mes("been saved here, inside")
    |> mes("of the Kafra Corporation")
    |> mes("Headquarters. Thank you.")
    |> next()
    |> savepoint("aldeba_in", 96, 179)
    |> mes("[Kafra Leilah]")
    |> mes("Please make use of")
    |> mes("the Kafra Services that are")
    |> mes("available throughout all of")
    |> mes("Midgard. Thank you for")
    |> mes("visiting the Kafra Headquarters.")
    |> close()
    |> cutin("", 255)
  end

  # rAthena `close3` ends the script, so the fee check cannot fall through to the service.
  defp use_storage(ctx) do
    if zeny(ctx) < @storage_fee do
      ctx
      |> mes("[Kafra Leilah]")
      |> mes("Excuse me, but it")
      |> mes("seems that you don't")
      |> mes("have the #{@storage_fee} zeny to pay")
      |> mes("the Storage access fee...")
      |> close()
      |> cutin("", 255)
    else
      open_storage(ctx)
    end
  end

  defp open_storage(ctx) do
    reserve_points = get_char_var(ctx, :RESRVPTS, 0) + div(@storage_fee, @reserve_point_divisor)

    ctx =
      ctx
      |> mes("[Kafra Leilah]")
      |> mes("Although this facility is")
      |> mes("exclusively intended for")
      |> mes("the training of Kafra Employee")
      |> mes("and administrative functions,")
      |> mes("I'll access your Storage for you.")
      |> next()
      |> pay_zeny(@storage_fee)
      |> set_char_var(:RESRVPTS, reserve_points)
      |> mes("[Kafra Leilah]")
      |> mes("In the future, please")
      |> mes("ask the Kafra Employee on")
      |> mes("duty if you wish to use")
      |> mes("any of the Kafra Services.")
      |> mes("Thank you for your patronage.")

    {ctx, _} = FCheckkafcode.call(ctx, [])

    ctx
    |> close()
    |> openstorage()
    |> cutin("", 255)
  end

  defp rent_pushcart(ctx) do
    ctx
    |> mes("[Kafra Leilah]")
    |> mes("My apologies, but I'm")
    |> mes("not on duty. I'd assist you")
    |> mes("if I could, but actually don't")
    |> mes("have any available Pushcarts.")
    |> mes("Why don't you ask another Kafra")
    |> mes("Employee for assistance?")
    |> next()
    |> mes("[Kafra Leilah]")
    |> mes("Kafra Employees are")
    |> mes("stationed all over the")
    |> mes("Midgard continent,")
    |> mes("and you should be able to find")
    |> mes("plenty outside in Al De Baran.")
    |> close()
    |> cutin("", 255)
  end

  defp cancel(ctx) do
    ctx
    |> mes("[Kafra Leilah]")
    |> mes("^666666*Whew...*^000000")
    |> mes("Great, because I'm")
    |> mes("actually on my break")
    |> mes("right now. Choosing")
    |> mes("''Cancel'' was a good")
    |> mes("move on your part.")
    |> close()
    |> cutin("", 255)
  end
end
