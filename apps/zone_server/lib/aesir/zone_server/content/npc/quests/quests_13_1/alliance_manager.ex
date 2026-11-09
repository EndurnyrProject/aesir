defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.AllianceManager do
  @moduledoc """
  Alliance Manager#ra, the Freya-worshipping manager who hears the player's report on the
  three-kingdom alliance.

  ## Behavior

  - At step 15 takes the alliance status report, advances quest 10071 to 10072 and sets
    `ep13_ryu` to 16.
  - At step 16 only gloats about the three kingdoms' success.
  - Otherwise reveals his own designs on Ash-Vacuum.

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
        map: "ra_temple",
        x: 119,
        y: 113,
        dir: 3,
        sprite: 935,
        name: "Alliance Manager",
        scope: :shared,
        unique_name: "Alliance Manager#ra"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_ryu, 0) do
      16 -> freya_blessing(ctx)
      15 -> receive_report(ctx)
      _step -> private_plan(ctx)
    end
  end

  defp freya_blessing(ctx) do
    ctx
    |> mes("[Manager]")
    |> mes(
      "With blessings from the Goddess Freya! We three kingdoms will know success! It's all we want. ...Khkhkhkh..."
    )
    |> close()
  end

  defp receive_report(ctx) do
    ctx
    |> mes("[Manager]")
    |> mes("What brings you here, if you won't worship Freya? Just go away.")
    |> next()
    |> mes("[Manager]")
    |> mes("Hm, you've come here to report the status of the alliance? Ok, let me listen.")
    |> next()
    |> mes("[Manager]")
    |> mes("Hm, everything is going well")
    |> mes("and almost prepared for a good start... Hm-hmm...")
    |> next()
    |> mes("[Manager]")
    |> mes("I hate to meet people from Rune-Midgarts, but I can't avoid it.")
    |> next()
    |> mes("[Manager]")
    |> mes("We're all together for this mission now... They would sacrifice for Freya.")
    |> next()
    |> changequest(10071, 10072)
    |> set_char_var(:ep13_ryu, 16)
    |> mes("[Manager]")
    |> mes("Now you can go back.")
    |> mes("Just say I received the report of the status well.")
    |> close()
  end

  defp private_plan(ctx) do
    ctx
    |> mes("[Manager]")
    |> mes("Goddess Freya, keep us forever!!")
    |> next()
    |> mes("[Manager]")
    |> mes("Ash-Vacuum...")
    |> mes("It will be mine soon...")
    |> mes("Khkhkh!")
    |> close()
  end
end
