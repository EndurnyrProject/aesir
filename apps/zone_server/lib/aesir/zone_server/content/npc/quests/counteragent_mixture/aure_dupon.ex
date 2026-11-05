defmodule Aesir.ZoneServer.Content.Npc.Quests.CounteragentMixture.AureDupon do
  @moduledoc """
  Aure Dupon, a fatalistic Geffen resident who reads the player's fate.

  ## Behavior

  - Before the player knows where Morgenstein lives, muses about destiny and offers
    to talk or to hear about Morgenstein.
  - Pointing the player at Morgenstein's forge sets the `molgenstain` step to 2.
  - Once that step is 2, greets the player as fate and asks whether Morgenstein was
    found yet.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Komurka
    - L0ne_W0lf
    - Everade
    - Lupus
    - Darkchild
    - Nexon

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 181,
        y: 114,
        dir: 3,
        sprite: 82,
        name: "Aure Dupon",
        scope: :shared,
        unique_name: "Aure Dupon#cm"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :molgenstain, 0) == 2 do
      paths_cross_again(ctx)
    else
      musings_on_destiny(ctx)
    end
  end

  defp paths_cross_again(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aure Dupon]")
      |> mes("It seems that our")
      |> mes("paths yet cross again.")
      |> mes("Coincidence? It's more")
      |> mes("than that. This is ^0000FFfate^000000.")
      |> next()
      |> select(["Talk About Morgenstein", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Aure Dupon]")
      |> mes("Have you not met")
      |> mes("Morgenstein yet? He")
      |> mes("lives on the second floor")
      |> mes("of the Forge. Although we've")
      |> mes("just met, I must warn you not")
      |> mes("to get too close to him...")
      |> close()
    else
      go_then(ctx)
    end
  end

  defp musings_on_destiny(ctx) do
    ctx =
      ctx
      |> mes("[Aure Dupon]")
      |> mes("Time flows gently")
      |> mes("and subtly, but no")
      |> mes("force in this world")
      |> mes("can possibly stop it.")
      |> mes("Mankind is not even a")
      |> mes("mote in the grand scheme.")
      |> next()

    if get_char_var(ctx, :molgenstain, 0) > 0 do
      morgenstein_menu(ctx)
    else
      talk_menu(ctx)
    end
  end

  defp morgenstein_menu(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Ask About Morgenstein", "Cancel"])

    case choice do
      1 -> read_destiny(ctx)
      2 -> point_at_morgenstein(ctx)
      3 -> go_then(ctx)
      _ -> ctx
    end
  end

  defp talk_menu(ctx) do
    {ctx, choice} = select(ctx, ["Talk", "Cancel"])

    if choice == 1, do: read_destiny(ctx), else: go_then(ctx)
  end

  defp read_destiny(ctx) do
    ctx
    |> mes("[Aure Dupon]")
    |> mes("To have goals and focus")
    |> mes("is good, but to be obsessive")
    |> mes("about one single thing can be")
    |> mes("quite destructive. Relax, empty")
    |> mes("your mind, and let yourself be")
    |> mes("carried by the tides of destiny.")
    |> close()
  end

  defp point_at_morgenstein(ctx) do
    ctx
    |> set_char_var(:molgenstain, 2)
    |> mes("[Aure Dupon]")
    |> mes("Morgenstein...?")
    |> mes("The man is obsessed")
    |> mes("with conquering the forces")
    |> mes("that control our world. But")
    |> mes("you seem to be curious about")
    |> mes("him for some reason. Hmmm...")
    |> next()
    |> mes("[Aure Dupon]")
    |> mes("It would be best if you")
    |> mes("were to see Morgenstein")
    |> mes("and judge his character for")
    |> mes("yourself. You may find him in")
    |> mes("the second floor of the Geffen")
    |> mes("Forge. Go: It is your destiny.")
    |> close()
  end

  defp go_then(ctx) do
    ctx
    |> mes("[Aure Dupon]")
    |> mes("Go then, and")
    |> mes("may the tides of")
    |> mes("destiny carry you")
    |> mes("to where you must go.")
    |> close()
  end
end
