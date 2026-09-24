defmodule Aesir.ZoneServer.Content.Npc.Jobs.Novice.Supernovice.KafraEmployee do
  @moduledoc """
  A rogue Kafra Employee in Aldebaran who rents carts to Super Novices.

  ## Behavior

  - Offers Super Novices a cart rental for 1,900 zeny after a Push Cart reminder.
  - Refuses if a cart is already equipped or the player cannot pay; attaches the cart only
    when the player knows Push Cart, and awards Kafra reserve points on payment.
  - Sends every other class to a regular Kafra Employee.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Darkchild
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 54,
        y: 238,
        dir: 5,
        sprite: 117,
        name: "Kafra Employee",
        scope: :shared,
        unique_name: "Kafra Employee#sn"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:super_novice) do
      super_novice_offer(ctx)
    else
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Good da--Oops...!")
      |> mes("I don't think I can provide you")
      |> mes("with the services you want...")
      |> mes("Please go talk to another")
      |> mes("Kafra employee. I apologize")
      |> mes("for such inconvenience...")
      |> close()
    end
  end

  defp super_novice_offer(ctx) do
    ctx = mes(ctx, "[Kafra Employee]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(ctx, "Hello, Mister Super Novice~")
      else
        mes(ctx, "Hello, Super Novice, Ma'am.")
      end

    {ctx, choice} =
      ctx
      |> mes("You must have been really")
      |> mes("dissapointed that the other")
      |> mes("Kafra Employees wouldn't let")
      |> mes("you rent a cart from them.")
      |> mes("But don't you worry now...")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("I'm here to support you guys")
      |> mes("by providing carts...")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("^3355FF*whispers*^000000")
      |> mes("^555555I am not supposed to do this")
      |> mes("because it's against our")
      |> mes("company policy. But I felt")
      |> mes("really sorry for Super Novices")
      |> mes("...so here I am.^000000")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("Anyway, would you like to rent a cart? The service fee is 1,900 zeny.")
      |> next()
      |> select(["Rent a Cart.", "Cancel."])

    if choice == 1, do: push_cart_reminder(ctx), else: farewell(ctx)
  end

  defp push_cart_reminder(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kafra Employee]")
      |> mes("Oh, here's the thing...")
      |> mes("Have you learned the 'Push Cart'")
      |> mes("skill? I can just rent you a")
      |> mes("cart, but if you haven't")
      |> mes("learned to push it, you'll")
      |> mes("just be wasting your zeny.")
      |> next()
      |> mes("[Kafra Employee]")
      |> mes("So make sure that you have")
      |> mes("the 'Push Cart' skill already.")
      |> next()
      |> select(["Rent a Cart.", "Cancel."])

    if choice == 1, do: rent_cart(ctx), else: farewell(ctx)
  end

  defp rent_cart(ctx) do
    cond do
      Rathena.truthy?(checkcart(ctx)) ->
        ctx
        |> mes("[Kafra Employee]")
        |> mes("Oh, you've already equipped a cart.")
        |> close()

      zeny(ctx) >= 1899 ->
        ctx =
          ctx
          |> set_char_var(:RESRVPTS, get_char_var(ctx, :RESRVPTS, 0) + 190)
          |> pay_zeny(1900)

        ctx = if getskilllv(ctx, 39) > 0, do: setcart(ctx), else: ctx

        ctx
        |> mes("[Kafra Employee]")
        |> mes("Thank you for using my service.")
        |> mes("Although what I am doing might")
        |> mes("not be legitimate to other")
        |> mes("Kafra Employees, I strongly")
        |> mes("believe I am doing what's right for the customers.")
        |> close()

      true ->
        ctx
        |> mes("[Kafra Employee]")
        |> mes(
          "I am sorry, but you do not have enough zeny with you. The service fee is 1,900 zeny."
        )
        |> close()
    end
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Kafra Employee]")
    |> mes("Please come again.")
    |> mes("Thank you for using my services.")
    |> close()
  end
end
