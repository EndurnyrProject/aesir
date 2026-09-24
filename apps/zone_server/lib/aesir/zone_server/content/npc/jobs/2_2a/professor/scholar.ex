defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22a.Professor.Scholar do
  @moduledoc """
  Advances eligible High Magicians to Scholar (Professor) in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or thoughts on a lifetime of learning.
  - High Magicians above job level 39 whose pending advancement is Scholar are offered the
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
        y: 47,
        dir: 3,
        sprite: 743,
        name: "Scholar",
        scope: :shared,
        unique_name: "Scholar#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:professor) and
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
    |> mes("[Scholar]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Scholar]")
    |> mes("It takes a lifetime...")
    |> mes("Literally a lifetime")
    |> mes("to amass the knowledge")
    |> mes("necessary to become")
    |> mes("a Scholar...")
    |> next()
    |> mes("[Scholar]")
    |> mes("It's overwhelming.")
    |> mes("The more you learn, the")
    |> mes("more you discover what")
    |> mes("else you don't know.")
    |> mes("There's no end to the")
    |> mes("process of learning...")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Scholar]")
      |> mes("Midgard doesn't")
      |> mes("have enough Scholars to")
      |> mes("help usher in a new age")
      |> mes("of prosperity. The")
      |> mes("world needs you...")
      |> next()
      |> mes("[Scholar]")
      |> mes("Will you take this")
      |> mes("awesome responsibility?")
      |> mes("Will you serve Midgard")
      |> mes("as a Scholar?")
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
    |> mes("[Scholar]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Scholar]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:professor)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Scholar]")
    |> mes("Congratulations!")
    |> mes("As a Professor, I hope")
    |> mes("that you will take an")
    |> mes("active part in bringing")
    |> mes("the light of knowledge")
    |> mes("where there is darkness.")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Scholar]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Scholar]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
