defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.SecurityOfficer do
  @moduledoc """
  The Nineball, the Jawaii security officer and a former 1st Squad member questioned during
  the Megingjard Seal quest.

  ## Behavior

  - Outside the Megingjard seal phase he only welcomes visitors to the resort.
  - During the phase, players who have reached him hear his welcome; once past that step,
    every further visit is counted, and after five of them the player notices the sadness
    he hides about the 1st Squad.
  - Players not yet at his step, or past the fifth visit, get no reply.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii_in",
        x: 44,
        y: 110,
        dir: 0,
        sprite: 734,
        name: "Security Officer",
        scope: :shared,
        unique_name: "Security Officer#megin"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
         get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      talk(ctx, get_char_var(ctx, :god_eremes, 0))
    else
      ctx |> welcome() |> close()
    end
  end

  defp talk(ctx, 18) do
    ctx
    |> mes("[The Nineball]")
    |> mes("Welcome to Jawaii,")
    |> mes("the paradise resort!")
    |> next()
    |> mes("[The Nineball]")
    |> mes(
      "I'm the 'The Nineball', the security officer of Jawaii! If you encounter any trouble, or find any Singles, please don't hesitate to report to me as soon as you can~"
    )
    |> next()
    |> mes("[The Nineball]")
    |> mes("I've been told that there have")
    |> mes("been many unruly drunkards here")
    |> mes(
      "lately, but it is in our best interest to make your experience here as enjoyable as possible."
    )
    |> close()
  end

  defp talk(ctx, eremes) when eremes > 18,
    do: count_visit(ctx, get_char_var(ctx, :god_megin_5, 0))

  defp talk(ctx, _eremes), do: ctx

  defp count_visit(ctx, visits) when visits < 5 do
    ctx
    |> welcome()
    |> set_char_var(:god_megin_5, visits + 1)
    |> close()
  end

  defp count_visit(ctx, 5) do
    ctx
    |> mes(
      "^3355FFHe acted very bright and friendly, but for a fleeting moment, you were able to glimpse a hint of sadness in his eyes.^000000"
    )
    |> next()
    |> mes("^3355FFIt doesn't seem that")
    |> mes("you'll be able to get him")
    |> mes("to talk about what exactly")
    |> mes("happened in the 1st Squad...^000000")
    |> close()
  end

  defp count_visit(ctx, _visits), do: ctx

  defp welcome(ctx) do
    ctx
    |> mes("[The Nineball]")
    |> mes("Welcome to Jawaii,")
    |> mes("the paradise resort!")
    |> next()
    |> mes("[The Nineball]")
    |> mes(
      "I'm the 'The Nineball, the security officer of Jawaii! If you encounter any trouble, or find any Singles, please don't hesitate to report to me as soon as you can~"
    )
    |> next()
    |> mes("[The Nineball]")
    |> mes("I've been told that there have")
    |> mes(
      "been many unruly drunkards here lately, but it is in our best interest to make your experience here as enjoyable as possible."
    )
  end
end
