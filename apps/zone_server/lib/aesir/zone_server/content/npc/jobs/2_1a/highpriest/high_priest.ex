defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21a.Highpriest.HighPriest do
  @moduledoc """
  Advances eligible High Acolytes to High Priest in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or a prayer for protection from evil.
  - High Acolytes above job level 39 whose pending advancement is High Priest are offered the
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
        y: 42,
        dir: 5,
        sprite: 60,
        name: "High Priest",
        scope: :shared,
        unique_name: "High Priest#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:high_priest) and
      Rathena.job_id(class(ctx)) == Rathena.job_id(:acolyte_high) and job_level(ctx) > 39
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
    |> mes("[High Priest]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[High Priest]")
    |> mes("Through the power")
    |> mes("of holiness, may we")
    |> mes("find peace, strength")
    |> mes("and protection. Deliver")
    |> mes("us from the forces of evil...")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[High Priest]")
      |> mes("Our world is in")
      |> mes("need of people of")
      |> mes("talent and conviction.")
      |> mes("Please continue your")
      |> mes("good works as an even")
      |> mes("greater hero of holiness...")
      |> next()
      |> mes("[High Priest]")
      |> mes("Would you like")
      |> mes("to become a High Priest?")
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
    |> mes("[High Priest]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[High Priest]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:high_priest)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[High Priest]")
    |> mes("Congratulations.")
    |> mes("As a High Priest,")
    |> mes("I hope you will guide")
    |> mes("others upon the path")
    |> mes("to holiness...")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[High Priest]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[High Priest]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
