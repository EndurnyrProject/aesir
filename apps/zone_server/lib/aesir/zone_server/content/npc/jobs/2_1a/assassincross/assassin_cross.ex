defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21a.Assassincross.AssassinCross do
  @moduledoc """
  Advances eligible High Thieves to Assassin Cross in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or a word about the warriors of the desert.
  - High Thieves above job level 39 whose pending advancement is Assassin Cross are offered the
    job change once all their skill points are spent; accepting clears the pending advancement.
  - Everyone else is welcomed to Valhalla.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Nana
    - Lupus
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "valkyrie",
        x: 44,
        y: 58,
        dir: 5,
        sprite: 725,
        name: "Assassin Cross",
        scope: :shared,
        unique_name: "Assassin Cross#Valkyrie"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ADVJOB, 0) == 0 or upper(ctx) != 1 -> greet_non_candidate(ctx)
      eligible_for_advancement?(ctx) -> offer_advancement(ctx)
      true -> welcome_to_valhalla(ctx)
    end
  end

  defp eligible_for_advancement?(ctx) do
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:assassin_cross) and
      Rathena.job_id(class(ctx)) == Rathena.job_id(:thief_high) and job_level(ctx) > 39
  end

  defp greet_non_candidate(ctx) do
    if Enum.random(1..10) > 4 do
      congratulate(ctx)
    else
      share_creed(ctx)
    end
  end

  defp congratulate(ctx) do
    ctx
    |> mes("[Assassin Cross]")
    |> mes("Congratulations...")
    |> next()
    |> mes("[Assassin Cross]")
    |> mes("...")
    |> next()
    |> mes("[Assassin Cross]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Assassin Cross]")
    |> mes("...")
    |> mes("......")
    |> mes("Honor to")
    |> mes("the warriors.")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Assassin Cross]")
    |> mes("We are the warriors")
    |> mes("of the desert. Nobody")
    |> mes("looks down upon us.")
    |> mes("Nobody...")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Assassin Cross]")
      |> mes("The time has come.")
      |> mes("The world needs you...")
      |> mes("More than ever.")
      |> next()
      |> mes("[Assassin Cross]")
      |> mes(
        "I ask that you continue to live in the shadows, but as an even greater Assassin with a new appearance."
      )
      |> next()
      |> mes("[Assassin Cross]")
      |> mes("Will you become")
      |> mes("an Assassin Cross?")
      |> next()
      |> select(["No.", "Yes."])

    cond do
      choice == 1 -> decline_advancement(ctx)
      Rathena.truthy?(skill_point(ctx)) -> request_skill_points_spent(ctx)
      true -> advance(ctx)
    end
  end

  defp decline_advancement(ctx) do
    ctx
    |> mes("[Assassin Cross]")
    |> mes("When you are")
    |> mes("ready, come back.")
    |> next()
    |> mes("[Assassin Cross]")
    |> mes("Honor to")
    |> mes("the warriors.")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Assassin Cross]")
    |> mes("You still haven't")
    |> mes("learned everything")
    |> mes("that you can.")
    |> next()
    |> mes("[Assassin Cross]")
    |> mes("Use all your")
    |> mes("Skill Points")
    |> mes("and then come back.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:assassin_cross)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Assassin Cross]")
    |> mes("Congratulations.")
    |> mes("As an Assassin Cross,")
    |> mes("I hope that you fight for a brighter future within the darkness.")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Assassin Cross]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Assassin Cross]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors.")
    |> close()
  end
end
