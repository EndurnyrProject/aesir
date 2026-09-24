defmodule Aesir.ZoneServer.Content.Npc.Jobs.Valkyrie.Valkyrie do
  @moduledoc """
  The Valkyrie of Valhalla, who rebirths eligible second-class characters as High Novices.

  ## Behavior

  - Welcomes characters who are already reborn or transcendent.
  - Sends away characters who are not second class at base level 99 and job level 50 or
    higher, or who still carry items, zeny, a cart, a falcon, a mount, or unused skill
    points.
  - Rebirths eligible characters as High Novices, remembering their advanced job, resets
    their level, clears job quest variables, grants First Aid and Play Dead, and gives a
    Knife and Cotton Shirt.
  - Warps the reborn character to the home town of their advanced job.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Nana
    - Poki
    - Lupus
    - L0ne_W0lf
    - Mass Zero
    - Silentdragon
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "valkyrie",
        x: 48,
        y: 86,
        dir: 4,
        sprite: 811,
        name: "Valkyrie",
        scope: :shared,
        unique_name: "Valkyrie#"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ADVJOB, 0) != 0 or upper(ctx) == 1 -> welcome_honored(ctx)
      rebirth_candidate?(ctx) -> prepare_rebirth(ctx)
      true -> turn_away_uninvited(ctx)
    end
  end

  defp rebirth_candidate?(ctx) do
    base_level(ctx) > 98 and job_level(ctx) > 49 and
      Rathena.job_id(class(ctx)) >= Rathena.job_id(:knight) and
      Rathena.job_id(class(ctx)) <= Rathena.job_id(:crusader2)
  end

  defp welcome_honored(ctx) do
    ctx
    |> mes("[Valkyrie]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Valkyrie]")
    |> mes("Please make")
    |> mes("yourself comfortable")
    |> mes("while you are here.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp turn_away_uninvited(ctx) do
    ctx
    |> mes("[Valkyrie]")
    |> mes("Welcome")
    |> mes("to Valhalla,")
    |> mes("the Hall of Honor.")
    |> next()
    |> mes("[Valkyrie]")
    |> mes(
      "Unfortunately, you have not yet been invited here. I ask you to leave immediately. Honor to the warriors!"
    )
    |> close()
    |> warp("yuno_in02", 93, 205)
  end

  defp prepare_rebirth(ctx) do
    ctx =
      ctx
      |> mes("[Valkyrie]")
      |> mes("Welcome")
      |> mes("to Valhalla,")
      |> mes("the Hall of Honor.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes("You will now end")
      |> mes("your present life and")
      |> mes("begin an entirely new life.")
      |> mes("Honor to the warriors!")
      |> next()

    if weight(ctx) > 0 or zeny(ctx) > 0 or checkcart(ctx) != 0 or checkfalcon(ctx) != 0 or
         ismounting(ctx) != 0 do
      demand_empty_hands(ctx)
    else
      confirm_detachment(ctx)
    end
  end

  defp demand_empty_hands(ctx) do
    ctx
    |> mes("[Valkyrie]")
    |> mes("There are a few things you must")
    |> mes("do before we start. You must")
    |> mes("first empty your mind and body.")
    |> mes("Honor comes when you abandon")
    |> mes("all your selfish desires...")
    |> next()
    |> mes("[Valkyrie]")
    |> mes(
      "You cannot take anything with you to the next life. Your items, zeny, pets and Pushcart all have to be left behind."
    )
    |> next()
    |> mes("[Valkyrie]")
    |> mes("When you are ready")
    |> mes("please return to me,")
    |> mes("brave adventurer.")
    |> close()
    |> warp("yuno_in02", 93, 205)
  end

  defp confirm_detachment(ctx) do
    ctx =
      ctx
      |> mes("[Valkyrie]")
      |> mes("I see you've already")
      |> mes("released yourself from")
      |> mes("all worldy attachments,")
      |> mes("#{char_name(ctx, 0)}.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes(
        "That's an admirable attitude for an adventurer such as yourself. Honor comes when you abandon all personal desires for the sake of mankind."
      )
      |> next()

    if Rathena.truthy?(skill_point(ctx)) do
      ctx
      |> mes("[Valkyrie]")
      |> mes("Hmm... I sense that you have")
      |> mes("some lingering attachment or")
      |> mes("unfinished business in your")
      |> mes("current life. Take care of that,")
      |> mes("and bring closure to your present life.")
      |> close()
      |> warp("yuno_in02", 93, 205)
    else
      rebirth(ctx)
    end
  end

  defp rebirth(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Valkyrie]")
      |> mes("Now, let me remove all")
      |> mes("of your present memories...")
      |> mes("However, you will be able to")
      |> mes("remember the most honorable")
      |> mes("moments of this life.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes("With one,")
      |> mes("I will ask the")
      |> mes("goddess Urd to remove")
      |> mes("all of your present")
      |> mes("memories.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes("With two,")
      |> mes("I will ask the")
      |> mes("goddess Verdandi to keep")
      |> mes("and record the most honorable moments of your present life.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes("With three,")
      |> mes("I will ask the")
      |> mes("goddess Skuld to")
      |> mes("guide you to your")
      |> mes("next life.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes("One...")
      |> FClearjobvar.call([])

    ctx =
      ctx
      |> next()
      |> mes("[Valkyrie]")
      |> mes("One...")
      |> mes("Two......")
      |> next()
      |> mes("[Valkyrie]")
      |> mes("One...")
      |> mes("Two......")
      |> mes("And Three.")

    ctx =
      ctx
      |> set_char_var(:ADVJOB, Rathena.job_id(class(ctx)) + Rathena.job_id(:novice_high))
      |> replace_advjob(Rathena.job_id(:lord_knight2), Rathena.job_id(:lord_knight))
      |> replace_advjob(Rathena.job_id(:paladin2), Rathena.job_id(:paladin))
      |> jobchange(:novice_high)
      |> resetlvl(1)

    ctx =
      ctx
      |> set_char_var(
        :MISC_QUEST,
        :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), :erlang.bnot(1024))
      )
      |> skill(142, 1, :permanent)
      |> skill(143, 1, :permanent)
      |> completequest(1000)
      |> next()
      |> mes("[Valkyrie]")
      |> mes("Congratulations.")
      |> mes("You are now reborn")
      |> mes("into a brand new life.")
      |> mes("Please take these small gifts")
      |> mes("in preparation for your new adventures.")
      |> give_item(1202, 1)
      |> give_item(2302, 1)
      |> next()
      |> mes("[Valkyrie]")
      |> mes(
        "I wish that the release the goddess Urd has granted you proves to be a blessing. I hope that the memories Verdandi has recorded will always honor you."
      )
      |> next()
      |> mes("[Valkyrie]")
      |> mes(
        "And I pray that the new life to which the goddess Skuld will guide you will be even more honorable than your last."
      )
      |> close()

    warp_to_home_town(ctx, get_char_var(ctx, :ADVJOB, 0))
  end

  defp replace_advjob(ctx, from, to) do
    if get_char_var(ctx, :ADVJOB, 0) == from do
      set_char_var(ctx, :ADVJOB, to)
    else
      ctx
    end
  end

  defp warp_to_home_town(ctx, advjob) when advjob in [4008, 4015] do
    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "izlude", 129, 97)
    else
      warp(ctx, "izlude", 94, 103)
    end
  end

  defp warp_to_home_town(ctx, advjob) when advjob in [4009, 4016],
    do: warp(ctx, "prontera", 273, 354)

  defp warp_to_home_town(ctx, advjob) when advjob in [4010, 4017],
    do: warp(ctx, "geffen", 120, 60)

  defp warp_to_home_town(ctx, advjob) when advjob in [4011, 4019],
    do: warp(ctx, "alberta", 116, 57)

  defp warp_to_home_town(ctx, advjob) when advjob in [4012, 4020, 4021],
    do: warp(ctx, "payon", 69, 100)

  defp warp_to_home_town(ctx, advjob) when advjob in [4013, 4018],
    do: warp(ctx, "morocc", 154, 50)

  defp warp_to_home_town(ctx, _advjob), do: warp(ctx, "yuno_in02", 93, 205)
end
