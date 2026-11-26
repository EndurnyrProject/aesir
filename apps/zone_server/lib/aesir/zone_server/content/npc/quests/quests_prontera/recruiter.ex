defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Recruiter do
  @moduledoc """
  The recruiter registers volunteers for the Prontera Culvert campaign.

  ## Behavior

  - Volunteers receive supplies and may be warped to the entrance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prt_in", x: 88, y: 105, dir: 2, sprite: 105, name: "Recruiter", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8)) do
      returning_volunteer(ctx)
    else
      recruit(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp returning_volunteer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Recruiter]")
      |> mes("Ah...")
      |> mes("I know those eyes.")
      |> mes("Full of compassion")
      |> mes("...and courage.")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Of course you're a volunteer for campaign to reclaim the Prontera Culvert. Would you let me warp you there?"
      )
      |> next()
      |> select(["Warp to Culvert Entrance.", "Quit."])

    if choice == 1, do: warp(ctx, "prt_fild05", 274, 208), else: close(ctx)
  end

  defp recruit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Recruiter]")
      |> mes(
        "Ah, let me inform you that the Capital Defense Headquarter of the Rune-Midgarts Kingdom has now decided to recruit a punitive force due to the Prontera Culvert's situation."
      )
      |> next()
      |> select(["Volunteer.", "Situation...?", "Quit."])

    case choice do
      1 ->
        {ctx, _} = scoped_call(ctx, [], &register_volunteer/2)

        ctx
        |> mes("[Recruiter]")
        |> mes("Are you ready, hero?")
        |> mes("I will now warp you")
        |> mes("to the Culvert.")
        |> next()
        |> warp("prt_fild05", 274, 208)

      2 ->
        explain_situation(ctx)

      3 ->
        close(ctx)

      _ ->
        ctx
    end
  end

  defp explain_situation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Recruiter]")
      |> mes("Haven't you heard...?")
      |> mes("The Prontera Culvert is infested with all kinds of filthy vermin!")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Due to the serious risk of water contamination, and the safety of Rune-Midgartsians, the Culvert has been quarantined by royal decree."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Needless to say, this has caused shortages in the water supply in our kingdom. Indeed, such a crisis in these dark times..."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes("Our people")
      |> mes("thirst for water...")
      |> mes("But they thirst")
      |> mes("even more...")
      |> mes("For a hero!")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Will you stand idly as the children of Rune-Midgarts suffer from parched throats and shed tears of dryness?! Would you bury our children?!"
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "Warriors! Rune-Midgarts is calling you! Cleanse this land's pestilence and cast out the vermin in the Culvert! Only you... Can make a difference."
      )
      |> next()
      |> select(["Volunteer.", "Quit."])

    if choice == 1 do
      {ctx, _} = scoped_call(ctx, [], &register_volunteer/2)

      ctx
      |> mes("[Recruiter]")
      |> mes("Adventurer...")
      |> mes("I will now warp you")
      |> mes("to the Prontera Culvert.")
      |> next()
      |> warp("prt_fild05", 274, 208)
    else
      ctx
      |> mes("[Recruiter]")
      |> mes(
        "Hmpf. Well. The next time you take a drink of water, just remember that an average of nine and a half children just died... ^990000Of thirst^000000."
      )
      |> close()
    end
  end

  defp register_volunteer(ctx, _args) do
    ctx =
      ctx
      |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 8))
      |> mes("[Recruiter]")
      |> mes("Your registration...")
      |> mes("is now complete.")
      |> next()
      |> mes("[Recruiter]")
      |> mes(
        "I would like to thank you for volunteering to do your part for our great kingdom. Here, take these provisions for your battles against the forces of darkness."
      )
      |> next()
      |> mes("[Recruiter]")
      |> mes("3 Red Potions, 1 Milk,")
      |> mes("and 1 Orange Potion")
      |> mes("...to give you hope.")
      |> give_item(501, 3)
      |> give_item(519, 1)
      |> give_item(502, 1)
      |> next()

    {ctx, nil}
  end
end
