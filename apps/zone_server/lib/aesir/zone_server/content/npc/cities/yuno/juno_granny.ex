defmodule Aesir.ZoneServer.Content.Npc.Cities.Yuno.JunoGranny do
  @moduledoc """
  Foretells encounters around Juno and occasionally offers candy.

  ## Behavior

  - Usually foretells an encounter with the Lord of the Dead.
  - On a rare roll, offers candy to players carrying at least 1,000 zeny.
  - Charges 1,000 zeny and gives one Candy when the offer is accepted.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 337,
        y: 227,
        dir: 4,
        sprite: 103,
        name: "Juno Granny",
        scope: :shared,
        unique_name: "Juno Granny#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Granny]")

    if Enum.random(1..50) == 1 do
      offer_candy(ctx)
    else
      foretell_lord_of_the_dead(ctx)
    end
  end

  defp offer_candy(ctx) do
    if zeny(ctx) > 999 do
      {ctx, choice} =
        ctx
        |> mes("So, do you enjoy candy?")
        |> next()
        |> mes("^3355FFGranny hands you some candy^000000.")
        |> next()
        |> mes("[Granny]")
        |> mes(
          "You've already chosen. It doesn't matter whether or not you get this candy. That doesn't matter at all. You have to understand why it's happened."
        )
        |> next()
        |> mes("[Granny]")
        |> mes("Here's ^3355FF1,000 zeny^000000.")
        |> mes("Do you accept this?")
        |> next()
        |> select(["Accept", "Do not accept"])

      if choice == 1 do
        accept_candy(ctx)
      else
        decline_candy(ctx)
      end
    else
      ctx
      |> mes("*Giggle giggle*")
      |> mes("The time has come.")
      |> mes("Well then...")
      |> close()
    end
  end

  defp accept_candy(ctx) do
    ctx
    |> mes("[Granny]")
    |> mes("*Giggle*")
    |> mes("There you go~")
    |> pay_zeny(1_000)
    |> give_item(529, 1)
    |> next()
    |> mes("[Granny]")
    |> mes("*Giggle*")
    |> mes("Well then...")
    |> mes("See you ~")
    |> close()
  end

  defp decline_candy(ctx) do
    ctx
    |> mes("[Granny]")
    |> mes(
      "Yes, that's right. Now you must ask yourself why you didn't accept the candy I offered."
    )
    |> close()
  end

  defp foretell_lord_of_the_dead(ctx) do
    ctx
    |> mes("I am an old Sage granny who foresees everything...")
    |> next()
    |> mes("[Granny]")
    |> mes(
      "Have you heard of a boss monster that has been around Juno for a long time? It's known only as the ^FF3355Lord of the Dead^000000."
    )
    |> next()
    |> mes("[Granny]")
    |> mes(
      "It is rumored to be from the realm of the dead. It brings many undead monsters with it, intending to lead living creatures to its cold and icy realm."
    )
    |> next()
    |> mes("[Granny]")
    |> mes(
      "You have already chosen whether or not you will challenge the Lord of the Dead. All you need to do right now is understand why you made the decision."
    )
    |> close()
  end
end
