defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22a.Stalker.Stalker do
  @moduledoc """
  Advances eligible High Thieves to Stalker in Valhalla.

  ## Behavior

  - Players who are not transcendent or have no pending advancement receive a random
    congratulation or thoughts on a Stalker's loyalty to allies.
  - High Thieves above job level 39 whose pending advancement is Stalker are offered the
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
        y: 58,
        dir: 3,
        sprite: 747,
        name: "Stalker",
        scope: :shared,
        unique_name: "Stalker#Valkyrie"
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
    get_char_var(ctx, :ADVJOB, 0) == Rathena.job_id(:stalker) and
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
    |> mes("[Stalker]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp share_creed(ctx) do
    ctx
    |> mes("[Stalker]")
    |> mes("Heh...")
    |> mes("It's tough")
    |> mes("being a hero")
    |> mes("and being shady,")
    |> mes("untrustworthy,")
    |> mes("sneaky...")
    |> next()
    |> mes("[Stalker]")
    |> mes("But when the")
    |> mes("going gets rough")
    |> mes("my pals know they")
    |> mes("can count on me.")
    |> mes("I need them and")
    |> mes("they need me.")
    |> close()
  end

  defp offer_advancement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Stalker]")
      |> mes("This world needs")
      |> mes("more heroes who are")
      |> mes("willing to walk the line")
      |> mes("between order and lawlessness.")
      |> next()
      |> mes("[Stalker]")
      |> mes("Are you ready")
      |> mes("to join the ranks")
      |> mes("of the sneakiest of")
      |> mes("warriors? Are you ready")
      |> mes("to become a Stalker?")
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
    |> mes("[Stalker]")
    |> mes("When you're ready,")
    |> mes("feel free to come back.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp request_skill_points_spent(ctx) do
    ctx
    |> mes("[Stalker]")
    |> mes("It is still possible for you to learn more skills. Please use")
    |> mes("all of your remaining Skill Points before returning to me.")
    |> close()
  end

  defp advance(ctx) do
    ctx
    |> jobchange(:stalker)
    |> set_char_var(:ADVJOB, 0)
    |> mes("[Stalker]")
    |> mes("Congratulations!")
    |> mes("As a Stalker, I hope")
    |> mes("you stab the right people")
    |> mes("in the back. Banish the")
    |> mes("wicked using their own")
    |> mes("dastardly methods!")
    |> close()
  end

  defp welcome_to_valhalla(ctx) do
    ctx
    |> mes("[Stalker]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Stalker]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end
end
