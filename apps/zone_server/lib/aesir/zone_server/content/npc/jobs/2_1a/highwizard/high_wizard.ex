defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21a.Highwizard.HighWizard do
  @moduledoc """
  Advances eligible High Magicians to High Wizard in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or a warning about wielding destructive magic.
  - High Magicians above job level 39 whose pending advancement is High Wizard are offered the
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
        y: 47,
        dir: 5,
        sprite: 735,
        name: "High Wizard",
        scope: :shared,
        unique_name: "High Wizard#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:high_wizard) and
      Rathena.job_id(class(ctx)) == Rathena.job_id(:mage_high) and job_level(ctx) > 39
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
    |> mes("[High Wizard]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[High Wizard]")
    |> mes("We High Wizards have")
    |> mes("the responsibility of")
    |> mes("using our destructive magic")
    |> mes("for the right purposes.")
    |> next()
    |> mes("[High Wizard]")
    |> mes("A lifetime of training")
    |> mes("is required before becoming")
    |> mes("a High Wizard. Can you imagine")
    |> mes("what would happen if our power")
    |> mes("was placed in the wrong hands?!")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[High Wizard]")
      |> mes("It is time.")
      |> mes("And Midgard has")
      |> mes("need of those who can")
      |> mes("wield the strongest of magic...")
      |> next()
      |> mes("[High Wizard]")
      |> mes("Would you like to")
      |> mes("become a High Wizard?")
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
    |> mes("[High Wizard]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honors to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[High Wizard]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:high_wizard)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[High Wizard]")
    |> mes("Congratulations.")
    |> mes("As a High Wizard,")
    |> mes("I hope use you use")
    |> mes("your powers to bring")
    |> mes("peace to the oppressed.")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[High Wizard]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[High Wizard]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
