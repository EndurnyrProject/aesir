defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22a.Champion.Champion do
  @moduledoc """
  Advances eligible High Acolytes to Champion in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or thoughts on what a Champion can master.
  - High Acolytes above job level 39 whose pending advancement is Champion are offered the
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
        y: 42,
        dir: 3,
        sprite: 52,
        name: "Champion",
        scope: :shared,
        unique_name: "Champion#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:champion) and
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
    |> mes("[Champion]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Champion]")
    |> mes("Skill.")
    |> mes("Speed.")
    |> mes("Strength.")
    |> mes("Agility.")
    |> next()
    |> mes("[Champion]")
    |> mes("A Champion can")
    |> mes("benefit from all")
    |> mes("these things. But")
    |> mes("one can only master")
    |> mes("so much in life...")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Champion]")
      |> mes("It's time.")
      |> mes("Time for great heroes")
      |> mes("to stand up against the")
      |> mes("forces of evil which plague")
      |> mes("the world of Midgard!")
      |> next()
      |> mes("[Champion]")
      |> mes("Would you like")
      |> mes("to become a Champion?")
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
    |> mes("[Champion]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Champion]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:champion)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Champion]")
    |> mes("Congratulations!")
    |> mes("Live as a Champion,")
    |> mes("and bring light into")
    |> mes("the world through the")
    |> mes("strength of your fists.")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Champion]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Champion]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
