defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Noyee do
  @moduledoc """
  Noyee explains armor slots and, during the Sleipnir Seal quest, points to a rumored
  laboratory in Juno.

  ## Behavior

  - Below base level 70, or once the Sleipnir seal has been broken, she explains slotted armor
    and Monster Cards.
  - Otherwise she shares the rumor about a laboratory in Juno and, the first time, starts the
    Sleipnir Seal quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 164,
        y: 200,
        dir: 4,
        sprite: 101,
        name: "Noyee",
        scope: :shared,
        unique_name: "Noyee#G"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) < 70 or
         get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check2", 0) do
      explain_slots(ctx)
    else
      ctx
      |> mes("[Noyee]")
      |> mes("You know, there's a very interesting place that looks")
      |> mes("sort of like a laboratory in Juno.")
      |> next()
      |> mes("[Noyee]")
      |> mes(
        "Anyway, no one is really sure if it is or not. Recently, it's been the focus of many rumors. I have no idea if any of them are true though."
      )
      |> close2()
      |> start_quest()
    end
  end

  defp explain_slots(ctx) do
    ctx
    |> mes("[Noyee]")
    |> mes(
      "Did you know that there's a difference between the armor you can buy from NPC shops and the kinds you obtain from hunting monsters?"
    )
    |> next()
    |> mes("[Noyee]")
    |> mes("The difference, my friend, is in the number of ^3355FFslots^000000 in your armor.")
    |> next()
    |> mes("[Noyee]")
    |> mes(
      "The same kind of Armor will have the same Defense. However, if an Armor has a slot, you can insert a Monster Card which will add an enhancement to that armor."
    )
    |> next()
    |> mes("[Noyee]")
    |> mes(
      "Both Monster Cards and Slotted Armors are rarely dropped by monsters, and are thus valuable commodies."
    )
    |> close()
  end

  defp start_quest(ctx) do
    if get_char_var(ctx, :god_sl_1, 0) == 0 do
      set_char_var(ctx, :god_sl_1, 1)
    else
      ctx
    end
  end
end
