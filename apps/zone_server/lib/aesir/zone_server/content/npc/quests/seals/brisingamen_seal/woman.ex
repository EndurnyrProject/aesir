defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Woman do
  @moduledoc """
  Rosa Ellenen mourns her sister Lowen at her grave.

  ## Behavior

  - Shares Lowen’s story as the seal quest progresses.
  - Passes a message and points the player toward the Crusader records.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 260,
        y: 354,
        dir: 4,
        sprite: 101,
        name: "Woman",
        scope: :shared,
        unique_name: "Woman#Rosa Ellenen"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        unavailable(ctx)

      get_server_var(ctx, "God3", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        unavailable(ctx)

      get_char_var(ctx, :god_brising, 0) > 33 ->
        visited_before(ctx)

      get_char_var(ctx, :god_brising, 0) == 21 ->
        lowens_message(ctx)

      get_char_var(ctx, :god_brising, 0) > 9 and get_char_var(ctx, :god_brising, 0) < 20 ->
        sister_grave(ctx)

      true ->
        greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp unavailable(ctx) do
    ctx
    |> mes("[Woman]")
    |> mes("Hm?")
    |> mes("What brings")
    |> mes("you here? It's")
    |> mes("kind of strange")
    |> mes("to come just to")
    |> mes("take a walk.")
    |> close()
  end

  defp visited_before(ctx) do
    ctx
    |> mes("[Rosa Ellenen]")
    |> mes("Are you the one")
    |> mes("who visited me before?")
    |> mes("Ah, of course.")
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("I'm not sure how")
    |> mes("to tell you this, but...")
    |> mes("This is Lowen's grave.")
    |> mes("And thank you.")
    |> close()
  end

  defp lowens_message(ctx) do
    ctx
    |> mes("[Rosa Ellenen]")
    |> mes("What are you")
    |> mes("talking about?")
    |> mes("A message from Lowen?")
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("What?!")
    |> mes("Why hasn't she")
    |> mes("gone to heaven yet?")
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("I hope you remember")
    |> mes("everything I'm going")
    |> mes("to tell you. She should")
    |> mes("go to heaven right now!")
    |> mes("I still don't understand...")
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes(
      "And please tell that praying fool that he shouldn't waste his time blaming himself. ^333333*Sigh*^000000 I still don't know why she chose to"
    )
    |> mes("speak to you.")
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes(
      "Let me tell you something. Lowen was a fencing prodigy. However, she always had trouble enduring the rigorous training and bearing the weight of the armor..."
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes(
      "But she loved fencing and always tried twice as hard to develop her physical strength so that she could serve God in battle."
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("Finally, she became a Crusader.")
    |> mes(
      "For a while things were great, but then she suddenly disappeared while on a mission to Geffen Dungeon."
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes(
      "Two years later, she was buried in this grave after her body was found by some adventurers. I was given the broken shards of armor and a blood stained ribbon she left behind."
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes(
      "I never really learned what exactly happened. And Hermite was always following her like she was his real sister. Ever since she died, he's changed. I hope he doesn't hurt himself..."
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes(
      "Something suspicious seems to have happened in the military, but they won't even talk to me about it. What could have happened?!"
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes(
      "In the end, I gave up trying to find the truth. After all, nothing can bring her back..."
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("Please tell her I'm fine,")
    |> mes("but I want to know why her")
    |> mes("soul hasn't moved on to")
    |> mes("heaven! Maybe...")
    |> next()
    |> mes("[Rose Ellenen]")
    |> mes("Maybe there's")
    |> mes("something in the")
    |> mes("Crusader Personnel")
    |> mes("Records that might")
    |> mes("explain something?")
    |> set_char_var(:god_brising, 25)
    |> close()
  end

  defp sister_grave(ctx) do
    ctx
    |> mes("[Rosa Ellenen]")
    |> mes("This is my little")
    |> mes("sister's grave...")
    |> mes("Her name was Lowen.")
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("Are you a friend")
    |> mes("of Lowen's? Hmmm?")
    |> mes("The man in the Sanctuary?")
    |> mes("That must be Hermite.")
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("He was shocked when Lowen")
    |> mes(
      "died but he doesn't have to blame himself for her death. I don't want him to suffer from the guilt."
    )
    |> next()
    |> mes("[Rosa Ellenen]")
    |> mes("Anyway, thank you for visiting")
    |> mes("my little sister. It's good to know she has friends, even after she's passed on.")
    |> set_char_var(:god_brising, 11)
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Rosa Ellenen]")
    |> mes("Oh hello...")
    |> mes("Have you come")
    |> mes("to pay your respects")
    |> mes("to someone here as well?")
    |> close()
  end
end
