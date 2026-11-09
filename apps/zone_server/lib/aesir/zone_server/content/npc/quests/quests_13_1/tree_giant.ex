defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.TreeGiant do
  @moduledoc """
  The half-tree giant of the Manuk field, met during the search for the Laphine.

  ## Behavior

  - Above base level 69, and while quest 2159 is still unstarted, describes the discovery and
    starts quest 2159.
  - Without a Laphine Ring equipped and below `ep13_2_rhea` 100 the giant's speech is
    unintelligible.
  - Otherwise asks where the Laphine reinforcements are.

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
        map: "man_fild03",
        x: 236,
        y: 105,
        dir: 3,
        sprite: 454,
        name: "Tree Giant",
        scope: :shared,
        unique_name: "Tree Giant#man"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @laphine_ring 2782
  @giant_report_quest 2159

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if base_level(ctx) > 69 and checkquest(ctx, @giant_report_quest) == -1 do
      announce_giant(ctx)
    else
      giant_encounter(ctx)
    end
  end

  # The discovery dialog closes, which ends the script: the giant encounter below only runs
  # for a player who already took the report quest or is too low level to find it.
  defp announce_giant(ctx) do
    ctx
    |> mes("You have found something moving between dry branches.")
    |> mes(
      "It appears to be a tree at first glance, but it turns out to be a giant that is half tree and half man."
    )
    |> next()
    |> emotion(:think)
    |> mes("[Tree Giant]")
    |> mes("TJDTMFJDNS CJFDI")
    |> mes("TKADLFDMF QKATOS")
    |> mes("EKDTLSDML DLFMADMS..")
    |> next()
    |> mes("The giant notices you, and looks very surprised.")
    |> mes("It is saying something, but you don't understand.")
    |> next()
    |> mes("You should report this to the united expedition quickly.")
    |> mes("Perhaps the guard captain of the expedition is the right person to report to.")
    |> setquest(@giant_report_quest)
    |> close()
  end

  defp giant_encounter(ctx) do
    ctx = emotion(ctx, :think)

    if not Rathena.truthy?(is_equipped(ctx, @laphine_ring)) and
         get_char_var(ctx, :ep13_2_rhea, 0) < 100 do
      cannot_understand(ctx)
    else
      laphine_question(ctx)
    end
  end

  defp cannot_understand(ctx) do
    ctx
    |> mes("[Tree Giant]")
    |> mes("TJDTMFJDNS CJFDI")
    |> mes("TKADLFDMF QKATOS")
    |> mes("EKDTLSDML DLFMADMS..")
    |> next()
    |> mes("The surprised giant is saying something to you, but you cannot understand.")
    |> close()
  end

  defp laphine_question(ctx) do
    ctx
    |> mes("[Tree Giant]")
    |> mes("Where are the Laphine reinforcements? I might have a problem.")
    |> close()
  end
end
