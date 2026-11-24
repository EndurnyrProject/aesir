defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier17062 do
  @moduledoc """
  Handles requests for replacement Transit Permits.

  ## Behavior

  - Offers a replacement for 10,000 zeny after the required quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_in02",
        x: 170,
        y: 62,
        dir: 4,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jiro]")
      |> mes("I'm Jiro, the administrator")
      |> mes("of this Palace. What can I do for you?")
      |> next()
      |> select(["Issue me a Transit Permit", "I want to live in Amatsu", "Nothing"])

    case choice do
      1 ->
        permit(ctx)

      2 ->
        ctx
        |> mes("[Jiro]")
        |> mes("That is impossible. You're free to")
        |> mes(
          "go anywhere in Amatsu, but my lord doesn't want to concern himself with immigration."
        )
        |> mes("Instead of that, you can stay here as long as you want.")
        |> close()

      3 ->
        ctx
        |> mes("[Jiro]")
        |> mes("Well then...")
        |> mes("Talk to me when you need help.")
        |> close()

      _ ->
        ctx
    end
  end

  defp permit(ctx) do
    cond do
      get_char_var(ctx, :event_amatsu, 0) != 6 ->
        ctx
        |> mes("[Gate Soldier]")
        |> mes("The lord announced that")
        |> mes("he grants guests from Midgard the right to go anywhere.")
        |> mes("You don't need me to issue you a Transit Permit.")
        |> close()

      count_item(ctx, 7160) > 0 ->
        ctx
        |> mes("[Jiro]")
        |> mes("You already have one...")
        |> mes("You don't need to have two of them.")
        |> close()

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Jiro]")
          |> mes("Did you lose your Transit Permit?")
          |> mes("You need to pay 10,000 zeny as a tax")
          |> mes("to issue another Transit Permit.")
          |> next()
          |> select(["Issue one", "Talk to you later"])

        if choice == 1 do
          ctx
          |> pay_zeny(10_000)
          |> give_item(7160, 1)
          |> mes("[Jiro]")
          |> mes("There you go.")
          |> mes("Don't lose it this time.")
          |> close()
        else
          ctx
          |> mes("[Jiro]")
          |> mes("Okay, then...")
          |> mes("Talk to me when you need help.")
          |> close()
        end
    end
  end
end
