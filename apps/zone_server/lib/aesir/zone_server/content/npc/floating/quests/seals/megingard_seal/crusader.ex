defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Seals.MegingardSeal.Crusader do
  @moduledoc """
  Max Von Shedough, the Crusader military judge who receives the petition against Rebarev Doug
  in the Megingjard Seal quest.

  ## Behavior

  - Outside the Megingjard seal phase he only introduces himself.
  - Handed the petition at the matching quest step, he accepts it, the server's second seal
    counter advances (announcing the seal's appearance or release, or the simultaneous release
    of all four seals) and the quest moves on.
  - Later he regrets that Rebarev Doug may be too influential to stand trial; before that he
    only introduces himself.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Crusader", scope: :shared, unique_name: "Crusader#God_"},
      %{
        map: "prt_cas",
        x: 241,
        y: 100,
        dir: 1,
        sprite: 734,
        name: "Crusader",
        unique_name: "Crusader#God",
        scope: :renewal
      },
      %{
        map: "prt_castle",
        x: 48,
        y: 164,
        dir: 0,
        sprite: 734,
        name: "Crusader",
        unique_name: "Crusader#God",
        scope: :pre_renewal
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
         get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      talk(ctx, get_char_var(ctx, :god_eremes, 0))
    else
      ctx
      |> welcome()
      |> mes("[Max Von Shedough]")
      |> mes("Let me introduce myself.")
      |> mes("My name is Max Von Shedough,")
      |> mes("the military judge! Sadly, even we Crusaders are not immune to corruption...")
      |> close()
    end
  end

  defp talk(ctx, eremes) when eremes > 22 and eremes < 25 do
    ctx =
      ctx
      |> welcome()
      |> mes("[Max Von Shedough]")
      |> mes("Let me introduce myself.")
      |> mes("My name is Max Von Shedough, the military judge! Do you have any business with me?")
      |> next()
      |> mes("^3355FFYou handed")
      |> mes("Max Von Shedough")
      |> mes("your petition against")
      |> mes("Rebarev Doug based on")
      |> mes("your investigation")
      |> mes("with Egnigem.^000000")
      |> next()
      |> mes("[Max Von Shedough]")
      |> mes("Hm? This is serious.")
      |> mes("Alright, I will investigate your claim to the best of my ability.")
      |> next()
      |> mes("[Max Von Shedough]")
      |> mes(
        "However, as of now, the petition you've just given me is considered classified information. Please keep this a military secret."
      )

    ctx
    |> set_server_var("God2", get_server_var(ctx, "God2", 0) + 1)
    |> announce_seal()
    |> set_char_var(:god_eremes, eremes + 2)
    |> close()
  end

  defp talk(ctx, eremes) when eremes > 26 do
    ctx
    |> mes("[Max Von Shedough]")
    |> mes("Unfortunately, I'm not sure if it's possible to hold a trial against Rebarev Doug.")
    |> next()
    |> mes("[Max Von Shedough]")
    |> mes(
      "Regrettably, it seems that he still has too much influence. Still, let me assure you that I'll do everything I can..."
    )
    |> next()
    |> mes("[Max Von Shedough]")
    |> mes("But count on me,")
    |> mes("I'll be doing my")
    |> mes("best to get him indicted.")
    |> close()
  end

  defp talk(ctx, _eremes) do
    ctx
    |> welcome()
    |> mes("[Max Von Shedough]")
    |> mes("Let me introduce myself.")
    |> mes(
      "My name is Max Von Shedough, the military judge! Sadly, even we Crusaders are not immune to corruption..."
    )
    |> close()
  end

  defp announce_seal(ctx) do
    god2 = get_server_var(ctx, "God2", 0)

    cond do
      god2 == get_server_temp_var(ctx, "god_check1", 0) ->
        announce(ctx, "The 2nd seal of [Megingjard] has appeared.", 0)

      god2 == get_server_temp_var(ctx, "god_check2", 0) ->
        announce(ctx, release_message(ctx), 0)

      true ->
        ctx
    end
  end

  defp release_message(ctx) do
    check2 = get_server_temp_var(ctx, "god_check2", 0)

    if get_server_var(ctx, "God1", 0) == check2 and get_server_var(ctx, "God2", 0) == check2 and
         get_server_var(ctx, "God3", 0) == check2 and get_server_var(ctx, "God4", 0) == check2 do
      "Four seals have been released at the same time with the seal of [Megingjard]."
    else
      "The 2nd seal of [Megingjard] has been released."
    end
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Max Von Shedough]")
    |> mes("Welcome, friend!")
    |> mes(
      "Here in the Prontera Castle, we Crusaders are busily preparing for the Holy War that is to come."
    )
    |> next()
  end
end
