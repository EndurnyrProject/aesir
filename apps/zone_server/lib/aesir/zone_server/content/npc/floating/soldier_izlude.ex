defmodule Aesir.ZoneServer.Content.Npc.Floating.SoldierIzlude do
  @moduledoc """
  Soldier guarding Izlude who chats about the Merchants' Registration System.

  ## Behavior

  - Lets the player choose whether to hear why he is in a good mood; declining
    ends the conversation with a farewell.
  - Accepting continues into the story of the Office of Prize Compensation,
    either confirming the player already knows that merchants buy what monsters
    drop or explaining it from the start.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Nexon
    - Silentdragon
    - MasterOfMuppets
    - Silent
    - Evera
    - CAHTEXHuK
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 165,
        y: 156,
        dir: 2,
        sprite: 105,
        name: "Soldier",
        scope: :renewal,
        unique_name: "Soldier#izlude"
      },
      %{
        map: "izlude_a",
        x: 165,
        y: 156,
        dir: 2,
        sprite: 105,
        name: "Soldier",
        scope: :renewal,
        unique_name: "Soldier#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 165,
        y: 156,
        dir: 2,
        sprite: 105,
        name: "Soldier",
        scope: :renewal,
        unique_name: "Soldier#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 165,
        y: 156,
        dir: 2,
        sprite: 105,
        name: "Soldier",
        scope: :renewal,
        unique_name: "Soldier#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 165,
        y: 156,
        dir: 2,
        sprite: 105,
        name: "Soldier",
        scope: :renewal,
        unique_name: "Soldier#izlude_d"
      },
      %{
        map: "izlude",
        x: 124,
        y: 178,
        dir: 2,
        sprite: 105,
        name: "Soldier",
        scope: :pre_renewal,
        unique_name: "Soldier#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Soldier]")
      |> mes("HeHeHeHe..HaHaHaHa ")
      |> mes("Huh? Why am I so happy?")
      |> mes("You wanna know?")
      |> next()
      |> select(["Sure, why?", "Not really, I don't care."])

    case answer do
      1 -> explain_why_he_is_happy(ctx)
      _ -> ctx |> mes("[Soldier]") |> mes("Okay Good Bye~~") |> close()
    end
  end

  defp explain_why_he_is_happy(ctx) do
    {ctx, knows_about_merchants} =
      ctx
      |> mes("[Soldier]")
      |> mes(
        "Ah~~ There's not much for us to do these days. You see, Merchants buy items dropped by monsters. But you knew that, right? "
      )
      |> next()
      |> select(["Of course", "Eh? Really?"])

    case knows_about_merchants do
      1 ->
        ctx
        |> mes("[Soldier]")
        |> mes(
          "HaHa~ In fact, that was actually part of our job. But there were more and more hunters who came to us in order to get paid and it became too much to handle."
        )
        |> next()
        |> registration_system()

      _ ->
        ctx
        |> mes("[Soldier]")
        |> mes(
          "What?! What do you mean you didn't know?! Well, you know you can get items by killing monsters. If you bring and sell those to a merchant, you can make some money. "
        )
        |> next()
        |> mes("[Soldier]")
        |> mes(
          "HaHa, in fact, that used to be part of our job. But there were more and more hunters who come in order to get paid, so it became too much to handle."
        )
        |> next()
        |> registration_system()
    end
  end

  defp registration_system(ctx) do
    ctx
    |> mes("[Soldier]")
    |> mes(
      "We had to work overtime every day. Ah, it was a nightmare...! Anyway, the government eventually made a wise decision in creating the Registration System."
    )
    |> next()
    |> mes("[Soldier]")
    |> mes(
      "The Office of Prize Compensation only pays those who have the Registration. Of course, you'd have to be a merchant and stay in the same place all day long."
    )
    |> next()
    |> mes("[Soldier]")
    |> mes(
      "The Office gives away the registration to any merchant who fulfills those requirements. So nowadays, the hunters sell their goods to the registered merchants."
    )
    |> next()
    |> mes("[Soldier]")
    |> mes(
      "So nowadays, the hunters sell their goods to the registered merchants.  Not too many people come to us for that anymore."
    )
    |> next()
    |> mes("[Soldier]")
    |> mes(
      "I mean we are still busy, but that's nothing compared to how it was before. People who have felt suffering know how to appreciate even the slightest comfort."
    )
    |> close()
  end
end
