defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22a.Clown.Minstrel do
  @moduledoc """
  Advances eligible High Archers to Minstrel (Clown) in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or an invitation to sing along.
  - High Archers above job level 39 whose pending advancement is Minstrel are offered the
    job change once all their skill points are spent; accepting clears the pending advancement.
  - Everyone else is welcomed to Valhalla.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Nana
    - Lupus
    - Vicious
    - Samuray22

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
        y: 54,
        dir: 3,
        sprite: 741,
        name: "Minstrel",
        scope: :shared,
        unique_name: "Minstrel#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:clown) and
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
    |> mes("[Minstrel]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Minstrel]")
    |> mes("Do you want to")
    |> mes("sing a song with me?")
    |> mes("Sha la la la la~")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Minstrel]")
      |> mes("The dreary world")
      |> mes("of mortals is in need")
      |> mes("of more cheerful song.")
      |> mes("Will you bring it to them")
      |> mes("and turn the tide in the")
      |> mes("battle against evil?")
      |> next()
      |> mes("[Minstrel]")
      |> mes("Will you do this")
      |> mes("for Midgard...")
      |> mes("As a Minstrel?")
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
    |> mes("[Minstrel]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Minstrel]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:clown)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Minstrel]")
    |> mes("Congratulations!")
    |> mes("As a Minstrel, your")
    |> mes("your songs will bring")
    |> mes("hope to your allies, and")
    |> mes("desperation to your foes.")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Minstrel]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Minstrel]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
