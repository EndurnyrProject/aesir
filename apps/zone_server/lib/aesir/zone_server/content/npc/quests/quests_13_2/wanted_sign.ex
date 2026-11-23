defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.WantedSign do
  @moduledoc """
  Advertises Rin's request to find the Dandelion gang.

  ## Behavior

  - Displays the notice after the tree-root quest has advanced.
  - Accepting the request starts the wanted quest.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 192,
        y: 239,
        dir: 4,
        sprite: 857,
        name: "Wanted Sign",
        scope: :shared,
        unique_name: "Wanted Sign#ep13_2ect01"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_mdrama, 0) > 5 do
      read_notice(ctx)
    else
      ctx |> mes("There must be someone who remove the wanted notice paper.") |> close()
    end
  end

  defp read_notice(ctx) do
    ctx =
      ctx
      |> mes("[Wanted]")
      |> mes(" ")
      |> mes("Wanted: Dandelion")
      |> mes("Requester: Rin")
      |> mes("Reward : treasure box.")
      |> mes(" ")
      |> mes("Notice : We thought that all of the Dandelion gang were terminated.")
      |> mes("But they weren't.")
      |> mes("I've heard that there was a Dandelion's black clothing found in Ash-Vacuum.")
      |> mes("There were some problems...")
      |> mes("I need someone to find the Dandelion and terminate them.")
      |> mes("I can provide a treasure box that I cherish.")
      |> mes("I've heard a rumor that he's in a cave somewhere..!")
      |> mes(" ")
      |> mes("PS> They have a bad reputation...")
      |> mes("So you may not want to go alone...")
      |> mes(" ")
      |> mes("PSS> I can't reward you directly...")
      |> mes("'Pinedel' will reward you once the deed is done..!")
      |> mes(" ")
      |> next()

    if get_char_var(ctx, :ep13_2_wanted, 0) == 0 do
      {ctx, choice} =
        ctx
        |> mes("Do you accept Rin's request?")
        |> select(["I accept that request.", "No, I can't."])

      if choice == 1 do
        ctx
        |> mes("I accepted Rin's request.")
        |> set_char_var(:ep13_2_wanted, 1)
        |> setquest(7076)
        |> close()
      else
        ctx |> mes("No, I won't get involved in it.") |> close()
      end
    else
      ctx |> mes("I've already decided to take the request.") |> close()
    end
  end
end
