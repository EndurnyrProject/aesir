defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.SmallFairy do
  @moduledoc """
  The small fairy of the Splendid field, met during the search that opens the Ash-Vacuum
  expedition quest line.

  ## Behavior

  - Above base level 69, while quest 2158 is unstarted, describes the discovery and starts
    quest 2158.
  - Without a Laphine Ring and below `ep13_2_rhea` 100 the fairy's speech is unintelligible.
  - Otherwise she asks whether the player is looking for the Sapha.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild02",
        x: 34,
        y: 223,
        dir: 5,
        sprite: 442,
        name: "Small Fairy",
        scope: :shared,
        unique_name: "Small Fairy#spl"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @laphine_ring 2782
  @fairy_report_quest 2158

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if base_level(ctx) > 69 and checkquest(ctx, @fairy_report_quest) == -1 do
      announce_fairy(ctx)
    else
      fairy_encounter(ctx)
    end
  end

  # The sighting dialog closes, which ends the script: the fairy encounter below only runs for
  # a player who already took the report quest or is too low level to find her.
  defp announce_fairy(ctx) do
    ctx
    |> mes("You find a little creature flying in the bushes.")
    |> mes("It has tiny wings on the back...")
    |> mes("It's a fairy!")
    |> next()
    |> emotion(:fret)
    |> mes("[Small Fairy]")
    |> mes("RLGHLRXLA TKANTLFDMS")
    |> mes("WJACK TNAHRDNJSDMFH")
    |> mes("WLSGHKWND !!")
    |> next()
    |> mes("The fairy notices you, and looks very surprised.")
    |> mes("It is saying something, but you don't understand.")
    |> next()
    |> mes("You should report this to the united expedition quickly.")
    |> mes("Perhaps the guard captain of the expedition is the right person to report to.")
    |> setquest(@fairy_report_quest)
    |> close()
  end

  defp fairy_encounter(ctx) do
    ctx = emotion(ctx, :fret)

    if not Rathena.truthy?(is_equipped(ctx, @laphine_ring)) and
         get_char_var(ctx, :ep13_2_rhea, 0) < 100 do
      cannot_understand(ctx)
    else
      sapha_question(ctx)
    end
  end

  defp cannot_understand(ctx) do
    ctx
    |> mes("[Small Fairy]")
    |> mes("RLGHLRXLA TKANTLFDMS")
    |> mes("WJACK TNAHRDNJSDMFH")
    |> mes("WLSGHKWND !!")
    |> next()
    |> mes(
      "The surprised fairy is saying something to you, but you cannot understand fairy language."
    )
    |> close()
  end

  defp sapha_question(ctx) do
    ctx
    |> mes("[Small Fairy]")
    |> mes("Who are you?! Are you looking for the Sapha!?")
    |> close()
  end
end
