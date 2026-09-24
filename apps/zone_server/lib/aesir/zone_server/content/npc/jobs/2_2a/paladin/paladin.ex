defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22a.Paladin.Paladin do
  @moduledoc """
  Advances eligible High Swordsmen to Paladin in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or a reminder of the approaching Holy War.
  - High Swordsmen above job level 39 whose pending advancement is Paladin are offered the
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
        x: 53,
        y: 39,
        dir: 3,
        sprite: 752,
        name: "Paladin",
        scope: :shared,
        unique_name: "Paladin#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:paladin) and
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
    |> mes("[Paladin]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Paladin]")
    |> mes("Do not forget")
    |> mes("that the Holy War")
    |> mes("is fast approaching!")
    |> mes("We must ready ourselves!")
    |> mes("May the light of justice")
    |> mes("always brighten our path!")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Paladin]")
      |> mes("The Holy War will")
      |> mes("be upon us before we")
      |> mes("know it. More than ever,")
      |> mes("we have need of strong men")
      |> mes("and women to fight for what")
      |> mes("is good and right.")
      |> next()
      |> mes("[Paladin]")
      |> mes("Will you fight on")
      |> mes("the side of righteousness")
      |> mes("as a Paladin?")
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
    |> mes("[Paladin]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Paladin]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:paladin)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Paladin]")
    |> mes("Congratulations.")
    |> mes("As a Paladin, I hope")
    |> mes("you will protect those")
    |> mes("weaker than you, and bring")
    |> mes("us victory in the upcoming")
    |> mes("war between good and evil.")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Paladin]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Paladin]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
