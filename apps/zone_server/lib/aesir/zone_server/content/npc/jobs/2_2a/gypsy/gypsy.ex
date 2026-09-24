defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22a.Gypsy.Gypsy do
  @moduledoc """
  Advances eligible High Archers to Gypsy in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or thoughts on dancing as a way of life.
  - High Archers above job level 39 whose pending advancement is Gypsy are offered the
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
        y: 56,
        dir: 3,
        sprite: 101,
        name: "Gypsy",
        scope: :shared,
        unique_name: "Gypsy#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:gypsy) and
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
    |> mes("[Gypsy]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Gypsy]")
    |> mes("Move left,")
    |> mes("move right~!")
    |> mes("And step...!")
    |> mes("Dancing can be")
    |> mes("more than a hobby.")
    |> mes("For me, it's a way of life~")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gypsy]")
      |> mes("The land of Midgard")
      |> mes("is in need of talented women")
      |> mes("to subtly change the balances")
      |> mes("in the battle between good")
      |> mes("and evil.")
      |> next()
      |> mes("[Gypsy]")
      |> mes("Are you ready")
      |> mes("to take up this role,")
      |> mes("and become a Gypsy?")
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
    |> mes("[Gypsy]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Gypsy]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:gypsy)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Gypsy]")
    |> mes("Congratulations!")
    |> mes("As a Gypsy, I know")
    |> mes("that your performances")
    |> mes("sway the hearts of all")
    |> mes("those who will be watching...")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Gypsy]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Gypsy]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
