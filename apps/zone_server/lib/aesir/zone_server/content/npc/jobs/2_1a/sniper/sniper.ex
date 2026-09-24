defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21a.Sniper.Sniper do
  @moduledoc """
  Advances eligible High Archers to Sniper in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or words on the Sniper's style of battle.
  - High Archers above job level 39 whose pending advancement is Sniper are offered the
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
        y: 55,
        dir: 5,
        sprite: 727,
        name: "Sniper",
        scope: :shared,
        unique_name: "Sniper#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:sniper) and
      Rathena.job_id(class(ctx)) == Rathena.job_id(:archer_high) and job_level(ctx) > 39
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
    |> mes("[Sniper]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Sniper]")
    |> mes("One shot.")
    |> mes("One kill.")
    |> mes("It's not so hard")
    |> mes("once you develop the")
    |> mes("vision for that style")
    |> mes("of battling.")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sniper]")
      |> mes("The world is in")
      |> mes("need of mighty Bowmen")
      |> mes("like you. Are you ready for")
      |> mes("the awesome responsibility?")
      |> next()
      |> mes("[Sniper]")
      |> mes("Are you willing to")
      |> mes("take the next step and")
      |> mes("become a Sniper?")
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
    |> mes("[Sniper]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Sniper]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:sniper)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Sniper]")
    |> mes("Congratulations!")
    |> mes("As a Sniper, I hope")
    |> mes("that the minions of evil")
    |> mes("will never be safe so")
    |> mes("long as they are in")
    |> mes("your sight!")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Sniper]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Sniper]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
