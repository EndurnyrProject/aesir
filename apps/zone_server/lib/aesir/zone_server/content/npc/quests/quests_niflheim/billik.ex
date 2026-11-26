defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNiflheim.Billik do
  @moduledoc """
  An Umbala adventurer who points Message Delivery questers to Feylin in the town of the dead.

  ## Behavior

  - Players carrying Erious' message who say they must meet someone learn about Feylin and
    his liking for roses, advancing the quest.
  - Players past this step, or who finished the quest, get a friendly greeting.
  - Players who have not started the quest are sent away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Evera
    - Lupus
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "umbala", x: 215, y: 181, dir: 3, sprite: 733, name: "Billik", scope: :shared}]

  @delivered 16_384

  @impl true
  def on_talk(ctx) do
    nif_revive = get_char_var(ctx, :nif_revive, 0)

    cond do
      nif_revive > 1 or :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), @delivered) != 0 ->
        greet(ctx)

      nif_revive == 1 ->
        ask_purpose(ctx)

      nif_revive == 0 ->
        dismiss(ctx)

      true ->
        ctx
    end
  end

  defp greet(ctx) do
    ctx
    |> mes("[Billik]")
    |> mes("Well, long time no see.")
    |> mes("If you have a chance in the")
    |> mes("future, let's meet in the")
    |> mes("town of the dead later.")
    |> mes("Hahahaha~")
    |> emotion(:best)
    |> close()
  end

  defp ask_purpose(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Billik]")
      |> mes("The Town of the dead...")
      |> mes("It's a very dangerous place.")
      |> mes("Why would you want to go there?")
      |> next()
      |> select(["I have to meet somebody there.", "It's a part of my adventure."])

    if choice == 1, do: introduce_feylin(ctx), else: warn_adventurer(ctx)
  end

  defp introduce_feylin(ctx) do
    ctx
    |> mes("[Billik]")
    |> mes("Someone you have to meet there...")
    |> mes("Hmm... I suppose you wish to")
    |> mes("contact the dead...")
    |> mes("I can also see that you're")
    |> mes("determined to go.")
    |> next()
    |> mes("[Billik]")
    |> mes("*Sigh* Okay, if you really want to")
    |> mes("go, you must find a man named")
    |> mes("'Feylin.' It's very important to")
    |> mes("let him know that I introduced")
    |> mes("him to you.")
    |> next()
    |> mes("[Billik]")
    |> mes("He's not very trusting, but he")
    |> mes("likes roses a lot, so bring a rose")
    |> mes("for him. That way, he'll know for")
    |> mes("sure that I've sent you.")
    |> set_char_var(:nif_revive, 2)
    |> changequest(11_038, 11_039)
    |> next()
    |> mes("[Billik]")
    |> mes("The town of the dead is located")
    |> mes("north of this place. Remember, it")
    |> mes("is very dangerous to go there,")
    |> mes("even for well experienced")
    |> mes("adventurers, so...")
    |> mes("Be careful.")
    |> close()
  end

  defp warn_adventurer(ctx) do
    ctx
    |> mes("[Billik]")
    |> mes("Hahaha~ I guess you like adventure")
    |> mes("as much as I do. Although it's a")
    |> mes("very dangrous place, you will be")
    |> mes("paid back for your effort after")
    |> mes("you get there. But be careful.")
    |> close()
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Billik]")
    |> mes("What brings you here? I'm busy,")
    |> mes("leave if you don't have any business.")
    |> close()
  end
end
