defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21a.Lordknight.LordKnight do
  @moduledoc """
  Advances eligible High Swordsmen to Lord Knight in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or words on a knight's duty to protect.
  - High Swordsmen above job level 39 whose pending advancement is Lord Knight are offered the
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
        y: 39,
        dir: 5,
        sprite: 56,
        name: "Lord Knight",
        scope: :shared,
        unique_name: "Lord Knight#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:lord_knight) and
      Rathena.job_id(class(ctx)) == Rathena.job_id(:swordman_high) and job_level(ctx) > 39
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
    |> mes("[Lord Knight]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Lord Knight]")
    |> mes("We Knights have an")
    |> mes("awesome responsibility...")
    |> mes("To serve and protect.")
    |> next()
    |> mes("[Lord Knight]")
    |> mes("Even at the cost")
    |> mes("of our own lives,")
    |> mes("we must safeguard the")
    |> mes("well being of our comrades.")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lord Knight]")
      |> mes("Your time has come!")
      |> mes("The world still needs you.")
      |> mes("Please continue your life")
      |> mes("as a hero with a new appearance.")
      |> next()
      |> mes("[Lord Knight]")
      |> mes("Would you like")
      |> mes("to become a Lord Knight?")
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
    |> mes("[Lord Knight]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Lord Knight]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:lord_knight)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Lord Knight]")
    |> mes("Congratulations!")
    |> mes("As a Lord Knight,")
    |> mes("I hope that you will be")
    |> mes("at the forefront of battle,")
    |> mes("and lead your allies to victory!")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Lord Knight]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Lord Knight]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
