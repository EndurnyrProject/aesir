defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Blacksmith.Wickebine do
  @moduledoc """
  Awaits a Gladius delivery as part of the Blacksmith job quest.

  ## Behavior

  - Accepts the Gladius from applicants on the delivery step and hands over a receipt.
  - Announces the delivery to the map and thanks applicants who already delivered.
  - Otherwise complains about the late order.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - Komurka
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - L0ne_W0lf
    - Yommy
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
        map: "morocc",
        x: 27,
        y: 112,
        dir: 4,
        sprite: 725,
        name: "Wickebine",
        scope: :shared,
        unique_name: "Wickebine#BLS"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :BSMITH_Q, 0) == 10 and count_item(ctx, 1219) > 0 -> offer_delivery(ctx)
      get_char_var(ctx, :BSMITH_Q, 0) == 14 -> thank_for_delivery(ctx)
      true -> await_gladius(ctx)
    end
  end

  defp offer_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("Job_Black_hucke01", 2)
      |> mes("[Wickebine]")
      |> mes("...!")
      |> mes("It's here!")
      |> next()
      |> mes("[Wickebine]")
      |> mes("This is what I ordered, right?")
      |> mes("I don't want any used or old Gladius that you might have!")
      |> next()
      |> select(["Whoops, not that one.", "I guarantee you it is new."])

    if choice == 1 do
      ctx
      |> cutin("Job_Black_hucke03", 2)
      |> mes("[Wickebine]")
      |> mes("Oooh...!")
      |> mes("Hurry up")
      |> mes("with my Gladius~")
      |> next()
      |> mes("- She seems to be upset. -")
      |> close()
      |> cutin("Job_Black_hucke03", 255)
    else
      deliver_gladius(ctx)
    end
  end

  defp deliver_gladius(ctx) do
    ctx =
      ctx
      |> cutin("Job_Black_hucke02", 2)
      |> mes("[Wickebine]")
      |> mes("Hah hah hah!")
      |> mes("Finally! Now...")
      |> mes("Let me have")
      |> mes("a look!")
      |> next()
      |> mes("- She looks very happy. -")
      |> next()
      |> set_char_var(:BSMITH_Q, 14)
      |> delitem(1219, 1)
      |> cutin("Job_Black_hucke01", 2)
      |> mes("[Wickebine]")
      |> mes("Are you with the")
      |> mes("Einbroch Blacksmith Guild?")
      |> mes("Give this message to Geschupenschte!")
      |> next()
      |> cutin("Job_Black_hucke03", 2)
      |> mes("[Wickebine]")
      |> mes("'^660000You're late!")
      |> mes("Do you know how long")
      |> mes("I've been waiting?!^000000'")
      |> next()
      |> cutin("Job_Black_hucke02", 2)
      |> mes("[Wickebine]")
      |> mes("But, this is also")
      |> mes("a masterfully crafted item.")
      |> mes("Tell him I'm satisfied with the quality of the workmanship.")
      |> next()
      |> give_item(1073, 1)
      |> emotion(:throb)
      |> mes("[Wickebine]")
      |> mes("Here's the receipt.")
      |> mes("I think you did")
      |> mes("a good job.")

    ctx
    |> mapannounce("morocc", "Thanks for delivering, #{char_name(ctx, 0)}~!", 1)
    |> close()
    |> cutin("Job_Black_hucke02", 255)
  end

  defp thank_for_delivery(ctx) do
    ctx
    |> emotion(:throb)
    |> cutin("Job_Black_hucke02", 2)
    |> mes("[Wickebine]")
    |> mes("Thanks for the delivery.")
    |> close()
    |> cutin("Job_Black_hucke02", 255)
  end

  defp await_gladius(ctx) do
    ctx
    |> cutin("Job_Black_hucke03", 2)
    |> mes("[Wickebine]")
    |> mes("...")
    |> next()
    |> mes("[Wickebine]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Wickebine]")
    |> mes("They're late.")
    |> mes("They're late,")
    |> mes("they're late,")
    |> mes("they're late~!")
    |> next()
    |> mes("[Wickebine]")
    |> mes(
      "How long does it take for something to ship from Geschupenschte? Usually, the Geffen Blacksmith Guild is pretty prompt..."
    )
    |> next()
    |> emotion(:throb)
    |> mes("[Wickebine]")
    |> mes("Ooohh...")
    |> mes("This is very")
    |> mes("upsetting...")
    |> close()
    |> cutin("Job_Black_hucke03", 255)
  end
end
